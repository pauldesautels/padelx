import { createHash } from 'node:crypto';
import { assertSafeFirestore, assertContributionAccountingReady } from './backend_environment.js';
import { DELETION_BARRIERS } from './account_state.js';

export class RatingReconciliationError extends Error {}

export function ratingIdentity(path) {
  const parts = path.split('/');
  if (parts.length !== 6 || parts[0] !== 'matches' || parts[2] !== 'ratingRaters'
      || parts[4] !== 'ratings' || parts.some((part) => !part)) throw new RatingReconciliationError('Invalid rating path.');
  return { matchId: parts[1], raterUid: parts[3], ratedUid: parts[5],
    contributionId: createHash('sha256').update(path).digest('hex') };
}

export function ratingAggregateAfterDelta(data, oldScore, newScore) {
  if (![oldScore, newScore].every((score) => Number.isInteger(score) && score >= 0 && score <= 5)) {
    throw new RatingReconciliationError('Invalid contribution score.');
  }
  const count = data.ratingCount ?? 0;
  const sum = data.ratingSum ?? 0;
  const nextCount = count + Number(newScore > 0) - Number(oldScore > 0);
  const nextSum = sum + newScore - oldScore;
  if (!Number.isSafeInteger(count) || !Number.isSafeInteger(sum)
      || count < 0 || sum < count || sum > count * 5
      || !Number.isSafeInteger(nextCount) || !Number.isSafeInteger(nextSum)
      || nextCount < 0 || nextSum < nextCount || nextSum > nextCount * 5) {
    // Do not clamp: that would silently discard other users' contributions.
    throw new RatingReconciliationError('Rating aggregate baseline inconsistent; reconciliation repair required.');
  }
  return { ratingCount: nextCount, ratingSum: nextSum,
    ratingAverage: nextCount === 0 ? 0 : nextSum / nextCount };
}

// Build a bounded reconciliation plan without writing. The caller can validate
// its lease and atomically apply this plan with its own durable checkpoint.
// Shared by trigger reconciliation and deletion; no second aggregate accounting.
export async function prepareRatingReconciliation(firestore, transaction, paths, { removeRatings = false } = {}) {
  assertContributionAccountingReady(assertSafeFirestore(firestore));
  if (!Array.isArray(paths) || paths.length > 100) throw new RatingReconciliationError('Invalid reconciliation page.');
  const effects = [];
  const profiles = new Map();
  for (const path of new Set(paths)) {
    try {
      const { raterUid, ratedUid, matchId, contributionId } = ratingIdentity(path);
      const ratingRef = firestore.doc(path);
      const contributionRef = firestore.collection('ratingContributions').doc(contributionId);
      const profileRef = firestore.collection('publicProfiles').doc(ratedUid);
      const [rating, contribution, profile, raterBarrier, ratedBarrier, match] = await transaction.getAll(
        ratingRef, contributionRef, profileRef,
        firestore.collection(DELETION_BARRIERS).doc(raterUid),
        firestore.collection(DELETION_BARRIERS).doc(ratedUid),
        firestore.collection('matches').doc(matchId),
      );
      if (removeRatings && rating.exists && ['matchId', 'raterUid', 'ratedUid'].some(
        (key) => rating.data()[key] !== ({ matchId, raterUid, ratedUid })[key])) {
        throw new RatingReconciliationError('Rating identity conflicts with path.');
      }
      const previous = contribution.data();
      if (previous && (previous.schemaVersion !== 1 || previous.ratingPath !== path
          || previous.raterUid !== raterUid || previous.ratedUid !== ratedUid
          || previous.matchId !== matchId || !Number.isInteger(previous.score)
          || previous.score < 1 || previous.score > 5)) throw new RatingReconciliationError('Invalid contribution baseline.');
      const data = rating.data();
      const matchData = match.data();
      const organizer = matchData?.creatorUid || matchData?.createdBy;
      const participant = (uid) => organizer === uid || (Array.isArray(matchData?.players)
        && matchData.players.some((player) => (player?.uid ?? player?.userId) === uid));
      const completed = typeof matchData?.scheduledAt?.toMillis === 'function'
        && matchData.scheduledAt.toMillis() <= Date.now();
      const eligible = !removeRatings && profile.exists && !raterBarrier.exists && !ratedBarrier.exists
        && data?.matchId === matchId && data?.raterUid === raterUid && data?.ratedUid === ratedUid
        && raterUid !== ratedUid && Number.isInteger(data?.rating) && data.rating >= 1 && data.rating <= 5
        && completed && matchData.status !== 'cancelled' && participant(raterUid) && participant(ratedUid);
      const oldScore = previous?.score ?? 0;
      const newScore = eligible ? data.rating : 0;
      if (profile.exists && (removeRatings || oldScore !== newScore || newScore > 0)) {
        const next = ratingAggregateAfterDelta(profiles.get(ratedUid)?.data ?? profile.data(), oldScore, newScore);
        profiles.set(ratedUid, { ref: profileRef, original: profile.data(), data: next });
      }
      if (newScore > 0 && oldScore !== newScore) {
        effects.push(() => transaction.set(contributionRef, { schemaVersion: 1, ratingPath: path,
          matchId, raterUid, ratedUid, score: newScore }));
      } else if (newScore === 0 && contribution.exists) {
        effects.push(() => transaction.delete(contributionRef));
      }
      if (removeRatings && rating.exists) effects.push(() => transaction.delete(ratingRef));
    } catch (error) {
      if (error instanceof RatingReconciliationError) error.recordPath = path;
      throw error;
    }
  }
  return () => {
    for (const { ref, original, data } of profiles.values()) {
      if (Object.entries(data).some(([key, value]) => original[key] !== value)) transaction.update(ref, data);
    }
    for (const effect of effects) effect();
  };
}

// Trigger payloads are deliberately ignored: current persisted state wins.
export async function reconcileRating(firestore, path) {
  assertContributionAccountingReady(assertSafeFirestore(firestore));
  await firestore.runTransaction(async (transaction) => {
    const apply = await prepareRatingReconciliation(firestore, transaction, [path]);
    apply();
  });
}
