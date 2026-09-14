import { HttpsError } from 'firebase-functions/v2/https';
import { requireActiveAccount } from './account_state.js';
import { matchMemberUids } from './messaging_policy.js';

const validId = (value) => typeof value === 'string' && value.length > 0
  && value.length <= 128 && !value.includes('/');

export async function getOwnRatingReceiptsOperation(firestore, request) {
  const uid = await requireActiveAccount(firestore, request);
  const { matchId, ratedUids } = request?.data ?? {};
  if (!validId(matchId) || !Array.isArray(ratedUids) || ratedUids.length > 8
      || ratedUids.some((value) => !validId(value) || value === uid)
      || new Set(ratedUids).size !== ratedUids.length) {
    throw new HttpsError('invalid-argument', 'Valid rating receipt request required.');
  }
  const match = await firestore.doc(`matches/${matchId}`).get();
  if (!match.exists) throw new HttpsError('not-found', 'Match unavailable.');
  if (!matchMemberUids(match.data()).includes(uid)) {
    throw new HttpsError('permission-denied', 'Rating receipts unavailable.');
  }
  const snapshots = await firestore.getAll(...ratedUids.map((ratedUid) =>
    firestore.doc(`matches/${matchId}/ratingRaters/${uid}/ratings/${ratedUid}`)));
  return { submittedRatedUids: ratedUids.filter((_, index) => snapshots[index].exists) };
}
