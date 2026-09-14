import { after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getOwnRatingReceiptsOperation } from '../functions/rating_receipts.js';
const projectId = 'demo-padelx-rating-receipts';
process.env.GCLOUD_PROJECT = projectId; process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'rating-receipt-tests'); const db = getFirestore(app);
const request = (uid, data) => ({ auth: { uid, token: { email_verified: true } }, data });
beforeEach(async () => { for (const c of await db.listCollections()) for (const r of await c.listDocuments()) await db.recursiveDelete(r); });
after(() => deleteApp(app));
test('receipt returns only submitted input identities and never scores', async () => {
  await db.doc('matches/match').set({ creatorUid: 'rater', players: [{ uid: 'rated' }, { uid: 'other' }] });
  await db.doc('matches/match/ratingRaters/rater/ratings/rated').set({ rating: 5, raterUid: 'rater', ratedUid: 'rated' });
  const result = await getOwnRatingReceiptsOperation(db, request('rater', { matchId: 'match', ratedUids: ['rated', 'other'] }));
  assert.deepEqual(result, { submittedRatedUids: ['rated'] });
  assert.equal(JSON.stringify(result).includes('rating'), false);
});
test('receipt rejects outsiders and malformed requests', async () => {
  await db.doc('matches/match').set({ creatorUid: 'rater', players: [{ uid: 'rated' }] });
  await assert.rejects(getOwnRatingReceiptsOperation(db, request('outsider', { matchId: 'match', ratedUids: ['rated'] })), { code: 'permission-denied' });
  await assert.rejects(getOwnRatingReceiptsOperation(db, request('rater', { matchId: 'match', ratedUids: ['rater'] })), { code: 'invalid-argument' });
});
