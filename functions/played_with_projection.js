import { createHash } from 'node:crypto';
import { assertPlayedWithProjectionReady, assertSafeFirestore } from './backend_environment.js';
import { DELETION_BARRIERS } from './account_state.js';

export const PLAYED_WITH_PROJECTION_VERSION = 1;
export const RECOVERY_PAGE_SIZE = 50;
export const RECOVERY_OVERLAP_MILLIS = 60 * 60 * 1000;
const STATE_PATH = 'socialProjectionState/completedMatches';

export class PlayedWithProjectionError extends Error {}

const validUid = (value) => typeof value === 'string' && value.length > 0
  && value.length <= 128 && !value.includes('/');
const timestampMillis = (value) => {
  const millis = value instanceof Date ? value.getTime() : value?.toMillis?.();
  return Number.isFinite(millis) ? millis : null;
};
const anonymous = (value) => value?.deleted === true && value.displayName === 'Deleted player'
  && Object.keys(value).length === 2;
const fail = () => { throw new PlayedWithProjectionError('Ambiguous match state.'); };

function identity(primary, legacy) {
  if ([primary, legacy].some((value) => value !== undefined && value !== '' && !validUid(value))) fail();
  if (primary && legacy && primary !== legacy) fail();
  return primary || legacy || '';
}

// Pure and deliberately strict. A malformed identity fails closed; Phase 8's
// exact anonymous placeholder is ignored without manufacturing an identity.
export function parseMatchPlayers(data, processingTime) {
  const scheduledMillis = timestampMillis(data?.scheduledAt);
  const processingMillis = timestampMillis(processingTime);
  if (scheduledMillis === null || processingMillis === null) fail();
  if (!Array.isArray(data.players) || data.players.length > 3) fail();
  const organizerUid = identity(data.creatorUid, data.createdBy);
  if (!organizerUid && !anonymous(data.organizer)) fail();
  const playerUids = data.players.map((player) => {
    if (!player || typeof player !== 'object' || Array.isArray(player)) fail();
    if (anonymous(player)) return '';
    const uid = identity(player.uid, player.userId);
    if (!uid) fail();
    return uid;
  });
  const participantUids = [organizerUid, ...playerUids].filter(Boolean);
  if (new Set(participantUids).size !== participantUids.length || participantUids.length > 4) fail();
  if (data.participantUids !== undefined && (!Array.isArray(data.participantUids)
      || data.participantUids.some((uid) => !validUid(uid))
      || new Set(data.participantUids).size !== data.participantUids.length
      || data.participantUids.length !== participantUids.length
      || participantUids.some((uid) => !data.participantUids.includes(uid)))) fail();
  return {
    participantUids,
    scheduledAt: data.scheduledAt,
    eligibleByMatch: scheduledMillis <= processingMillis && data.status !== 'cancelled',
  };
}

export function pairKey(left, right) {
  if (!validUid(left) || !validUid(right) || left === right) throw new PlayedWithProjectionError('Invalid pair.');
  return [left, right].sort().join('|');
}

export function contributionId(matchId, left, right) {
  if (!validUid(matchId)) throw new PlayedWithProjectionError('Invalid match ID.');
  return createHash('sha256').update(`${matchId}\0${pairKey(left, right)}`).digest('hex');
}

function safeCount(data, key) {
  const value = data?.[key] ?? 0;
  if (!Number.isSafeInteger(value) || value < 0) throw new PlayedWithProjectionError(`Invalid ${key} baseline.`);
  return value;
}

function pairs(uids) {
  const result = [];
  for (let left = 0; left < uids.length; left += 1) {
    for (let right = left + 1; right < uids.length; right += 1) result.push([uids[left], uids[right]]);
  }
  return result;
}

function sameTimestamp(left, right) {
  return timestampMillis(left) === timestampMillis(right);
}

export async function reconcilePlayedWithMatch(firestore, matchId, processingTime = new Date()) {
  assertPlayedWithProjectionReady(assertSafeFirestore(firestore));
  if (!validUid(matchId) || timestampMillis(processingTime) === null) {
    throw new PlayedWithProjectionError('Valid match and processing time required.');
  }
  await firestore.runTransaction(async (transaction) => {
    const matchRef = firestore.collection('matches').doc(matchId);
    const matchContributionRef = firestore.collection('playedWithMatchContributions').doc(matchId);
    const [matchSnapshot, previousSnapshot] = await transaction.getAll(matchRef, matchContributionRef);
    const previous = previousSnapshot.data();
    if (previous && (previous.projectionVersion !== PLAYED_WITH_PROJECTION_VERSION
        || previous.matchId !== matchId || !Array.isArray(previous.participantUids)
        || previous.participantUids.some((uid) => !validUid(uid))
        || new Set(previous.participantUids).size !== previous.participantUids.length
        || timestampMillis(previous.scheduledAt) === null)) {
      throw new PlayedWithProjectionError('Invalid match contribution baseline.');
    }

    let parsed = { participantUids: [], scheduledAt: previous?.scheduledAt, eligibleByMatch: false };
    if (matchSnapshot.exists) {
      try {
        parsed = parseMatchPlayers(matchSnapshot.data(), processingTime);
      } catch (error) {
        // Invalid canonical state contributes nothing. Any known prior
        // contribution is still safely reversible without guessing identity.
        if (!(error instanceof PlayedWithProjectionError)) throw error;
      }
    }
    const identityUids = [...new Set([...(previous?.participantUids ?? []), ...parsed.participantUids])];
    const accountRefs = identityUids.flatMap((uid) => [
      firestore.collection('users').doc(uid), firestore.collection('publicProfiles').doc(uid),
      firestore.collection(DELETION_BARRIERS).doc(uid),
    ]);
    const accountSnapshots = accountRefs.length ? await transaction.getAll(...accountRefs) : [];
    const accounts = new Map();
    identityUids.forEach((uid, index) => accounts.set(uid, {
      user: accountSnapshots[index * 3], profile: accountSnapshots[index * 3 + 1],
      barrier: accountSnapshots[index * 3 + 2],
    }));
    const active = (uid) => accounts.get(uid)?.user.exists && accounts.get(uid)?.profile.exists
      && !accounts.get(uid)?.barrier.exists;
    const nextUids = parsed.eligibleByMatch ? parsed.participantUids.filter(active) : [];
    const previousUids = previous?.participantUids ?? [];
    const affectedPairKeys = new Map();
    for (const pair of [...pairs(previousUids), ...pairs(nextUids)]) affectedPairKeys.set(pairKey(...pair), pair.sort());

    const pairState = new Map();
    for (const [key, pair] of affectedPairKeys) {
      const pairRef = firestore.collection('playedWithPairs').doc(createHash('sha256').update(key).digest('hex'));
      const contributionRef = firestore.collection('playedWithContributions').doc(contributionId(matchId, ...pair));
      const baseQuery = firestore.collection('playedWithContributions').where('pairKey', '==', key);
      const [pairSnapshot, contributionSnapshot, firstSnapshot, lastSnapshot] = await Promise.all([
        transaction.get(pairRef), transaction.get(contributionRef),
        transaction.get(baseQuery.orderBy('scheduledAt', 'asc').limit(2)),
        transaction.get(baseQuery.orderBy('scheduledAt', 'desc').limit(2)),
      ]);
      pairState.set(key, { pair, pairRef, contributionRef, pairSnapshot, contributionSnapshot,
        nearby: [...firstSnapshot.docs, ...lastSnapshot.docs] });
    }

    const playerDelta = new Map(identityUids.map((uid) => [uid,
      Number(nextUids.includes(uid)) - Number(previousUids.includes(uid))]));
    const repeatDelta = new Map(identityUids.map((uid) => [uid, 0]));
    const writes = [];
    for (const [key, state] of pairState) {
      const wasActive = pairs(previousUids).some((pair) => pairKey(...pair) === key);
      const isActive = pairs(nextUids).some((pair) => pairKey(...pair) === key);
      const storedActive = state.contributionSnapshot.exists;
      if (storedActive !== wasActive) throw new PlayedWithProjectionError('Pair contribution baseline inconsistent.');
      const oldCount = safeCount(state.pairSnapshot.data(), 'completedMatchCount');
      const newCount = oldCount + Number(isActive) - Number(wasActive);
      if (newCount < 0) throw new PlayedWithProjectionError('Pair count underflow.');
      if (oldCount < 2 && newCount >= 2) state.pair.forEach((uid) => repeatDelta.set(uid, repeatDelta.get(uid) + 1));
      if (oldCount >= 2 && newCount < 2) state.pair.forEach((uid) => repeatDelta.set(uid, repeatDelta.get(uid) - 1));

      const candidates = new Map();
      for (const doc of state.nearby) if (doc.id !== state.contributionRef.id) candidates.set(doc.id, doc.data());
      if (isActive) candidates.set(state.contributionRef.id, { matchId, pairKey: key, scheduledAt: parsed.scheduledAt });
      const ordered = [...candidates.values()].sort((a, b) => timestampMillis(a.scheduledAt) - timestampMillis(b.scheduledAt)
        || a.matchId.localeCompare(b.matchId));
      const first = ordered[0]; const last = ordered.at(-1);
      if (newCount === 0) {
        writes.push(() => transaction.delete(state.pairRef));
        for (const [uid, otherUid] of [state.pair, [...state.pair].reverse()]) {
          writes.push(() => transaction.delete(firestore.doc(`users/${uid}/playedWith/${otherUid}`)));
        }
      } else {
        if (!first || !last) throw new PlayedWithProjectionError('Pair extrema unavailable.');
        const pairData = { pairKey: key, participantUids: state.pair, firstPlayedAt: first.scheduledAt,
          lastPlayedAt: last.scheduledAt, lastMatchId: last.matchId, completedMatchCount: newCount,
          projectionVersion: PLAYED_WITH_PROJECTION_VERSION, updatedAt: processingTime };
        writes.push(() => transaction.set(state.pairRef, pairData));
        for (const [uid, otherUid] of [state.pair, [...state.pair].reverse()]) {
          if (!active(uid) || !active(otherUid)) continue;
          writes.push(() => transaction.set(firestore.doc(`users/${uid}/playedWith/${otherUid}`), {
            otherUid, firstPlayedAt: first.scheduledAt, lastPlayedAt: last.scheduledAt,
            lastMatchId: last.matchId, completedMatchCount: newCount,
            projectionVersion: PLAYED_WITH_PROJECTION_VERSION, updatedAt: processingTime,
          }));
        }
      }
      if (isActive) writes.push(() => transaction.set(state.contributionRef, {
        matchId, pairKey: key, participantUids: state.pair, scheduledAt: parsed.scheduledAt,
        projectionVersion: PLAYED_WITH_PROJECTION_VERSION,
      }));
      else if (storedActive) writes.push(() => transaction.delete(state.contributionRef));
    }

    for (const uid of identityUids) {
      const account = accounts.get(uid);
      if (!account.profile.exists || account.barrier.exists) continue;
      const matchDelta = playerDelta.get(uid) ?? 0;
      const repeats = repeatDelta.get(uid) ?? 0;
      if (matchDelta || repeats) {
        const oldMatches = safeCount(account.profile.data(), 'completedMatchCount');
        const oldRepeats = safeCount(account.profile.data(), 'repeatPlayerCount');
        if (oldMatches + matchDelta < 0 || oldRepeats + repeats < 0) fail();
        writes.push(() => transaction.update(account.profile.ref, {
          completedMatchCount: oldMatches + matchDelta, repeatPlayerCount: oldRepeats + repeats,
        }));
      }
    }
    if (nextUids.length >= 1) writes.push(() => transaction.set(matchContributionRef, {
      matchId, participantUids: nextUids, scheduledAt: parsed.scheduledAt,
      projectionVersion: PLAYED_WITH_PROJECTION_VERSION, updatedAt: processingTime,
    }));
    else if (previousSnapshot.exists) writes.push(() => transaction.delete(matchContributionRef));
    for (const write of writes) write();
  });
}

export async function recoverPlayedWithMatches(firestore, processingTime = new Date(), pageSize = RECOVERY_PAGE_SIZE) {
  assertPlayedWithProjectionReady(assertSafeFirestore(firestore));
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > RECOVERY_PAGE_SIZE) fail();
  const stateRef = firestore.doc(STATE_PATH);
  const stateSnapshot = await stateRef.get();
  const state = stateSnapshot.data();
  const nowMillis = timestampMillis(processingTime);
  if (nowMillis === null) fail();
  const continuing = timestampMillis(state?.cycleStart) !== null
    && timestampMillis(state?.cycleEnd) !== null && state?.afterScheduledAt && state?.afterMatchId;
  const cycleEnd = continuing ? state.cycleEnd : processingTime;
  const cycleStart = continuing ? state.cycleStart : timestampMillis(state?.cycleEnd) === null
    ? new Date(nowMillis - RECOVERY_OVERLAP_MILLIS)
    : new Date(timestampMillis(state.cycleEnd) - RECOVERY_OVERLAP_MILLIS);
  let query = firestore.collection('matches').where('scheduledAt', '>', cycleStart)
    .where('scheduledAt', '<=', cycleEnd).orderBy('scheduledAt').orderBy('__name__').limit(pageSize);
  if (continuing) query = query.startAfter(state.afterScheduledAt, state.afterMatchId);
  const page = await query.get();
  for (const doc of page.docs) await reconcilePlayedWithMatch(firestore, doc.id, processingTime);
  const last = page.docs.at(-1);
  if (page.size === pageSize) {
    await stateRef.set({ cycleStart, cycleEnd, afterScheduledAt: last.get('scheduledAt'),
      afterMatchId: last.id, updatedAt: processingTime });
    return { processed: page.size, complete: false };
  }
  await stateRef.set({ cycleStart: new Date(timestampMillis(cycleEnd) - RECOVERY_OVERLAP_MILLIS),
    cycleEnd: processingTime, afterScheduledAt: null, afterMatchId: null, updatedAt: processingTime });
  return { processed: page.size, complete: true };
}
