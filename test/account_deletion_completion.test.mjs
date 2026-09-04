import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { admitAccountDeletion, lockDeletionAuth } from '../functions/account_deletion.js';
import { dispatchAccountDeletion, acceptDeletedAuthUser, recoverAccountDeletions } from '../functions/account_deletion_dispatch.js';
import { acquireDeletionLease, runDeleteAuthDeletionPhase } from '../functions/account_deletion_worker.js';
import { prepareDeletion, preparationOptions } from '../tool/prepare_account_deletion.mjs';
const projectId = 'demo-padelx-completion';
process.env.GCLOUD_PROJECT = projectId; process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'completion');
const db = getFirestore(app), auth = getAuth(app); after(() => deleteApp(app));
const ref = uid => db.doc(`accountDeletionJobs/${uid}`);
const request = uid => ({ auth: { uid, token: { auth_time: Math.floor(Date.now()/1000) } }, data: {} });
async function finish(uid) {
  for (let i = 0; i < 20; i++) {
    await dispatchAccountDeletion(db, auth, uid);
    if ((await ref(uid).get()).data().status === 'completed') return;
  }
  assert.fail('deletion did not complete');
}
test('unverified incomplete user, lost response, duplicate dispatch, Auth finalization and minimal receipt', async () => {
  const uid = 'complete-user'; await auth.createUser({ uid, emailVerified: false });
  await admitAccountDeletion(db, auth, request(uid));
  const cutoff = (await ref(uid).get()).data().deletionRequestedAt;
  await admitAccountDeletion(db, auth, request(uid));
  await Promise.all([dispatchAccountDeletion(db, auth, uid), dispatchAccountDeletion(db, auth, uid)]);
  await finish(uid);
  await assert.rejects(auth.getUser(uid), { code: 'auth/user-not-found' });
  const job = (await ref(uid).get()).data();
  assert.equal(job.phase, 'complete'); assert.ok(job.completedAt);
  assert.ok(job.deletionRequestedAt.isEqual(cutoff));
  assert.deepEqual(Object.keys(job).sort(), ['completedAt','deletionRequestedAt','phase','schemaVersion','status','uid']);
  assert.equal((await db.doc(`accountDeletionOutbox/${uid}`).get()).data().status, 'consumed');
  await lockDeletionAuth(db, auth, uid); // Late admission trigger cannot regress completion.
  assert.equal((await ref(uid).get()).data().status, 'completed');
  await acceptDeletedAuthUser(db, uid); // Auth event after normal finalization.
  assert.ok((await ref(uid).get()).data().deletionRequestedAt.isEqual(cutoff));
});
test('direct Auth fallback uses pipeline and absent Auth is successful', async () => {
  const uid = 'external-delete'; await acceptDeletedAuthUser(db, uid); await finish(uid);
  assert.equal((await ref(uid).get()).data().status, 'completed');
});
test('Auth deletion requires verified phase, fences stale workers and does not complete on transient failure', async () => {
  const uid = 'finalization-failure'; await admitAccountDeletion(db, auth, request(uid));
  const lease = { leaseOwner: 'test', leaseToken: 'one' };
  await acquireDeletionLease(db, uid, lease);
  await assert.rejects(runDeleteAuthDeletionPhase(db, { deleteUser: () => assert.fail() }, uid, lease), /Invalid Auth/);
  await ref(uid).update({ leaseExpiresAt: new Date(0), leaseOwner: null });
  const cutoff = (await ref(uid).get()).data().deletionRequestedAt;
  await ref(uid).update({ phase: 'deleteAuth', verifyCheckpoint: { manifestDone: true, manifestAfter: null },
    verifyCutoff: cutoff, lastPhaseTransition: { from: 'verify', to: 'deleteAuth' } });
  const fresh = { leaseOwner: 'test', leaseToken: 'two' };
  assert.equal(await acquireDeletionLease(db, uid, fresh), true);
  await assert.rejects(runDeleteAuthDeletionPhase(db, auth, uid, lease), /lease lost/);
  await assert.rejects(runDeleteAuthDeletionPhase(db, { deleteUser: async () => { throw new Error('unavailable'); } }, uid, fresh));
  assert.equal((await ref(uid).get()).data().completedAt, null);
  await runDeleteAuthDeletionPhase(db, auth, uid, fresh);
  assert.equal((await ref(uid).get()).data().status, 'completed');
});
test('bounded recovery rejects invalid pages and production', async () => {
  await assert.rejects(recoverAccountDeletions(db, auth, { pageSize: 21 }));
  await assert.rejects(recoverAccountDeletions({ projectId: 'padelx-f168f' }, auth));
});
test('preparation is dry-run, blocker-first, idempotent and production-refusing', async () => {
  assert.throws(() => preparationOptions([]));
  assert.throws(() => preparationOptions(['--project=padelx-f168f','--apply','--writers-paused']));
  assert.throws(() => preparationOptions([`--project=${projectId}`,'--apply']));
  await db.doc('matches/missing/joinRequests/requester').set({ email: 'legacy@example.com' });
  const report = await prepareDeletion(db, { apply: true, writersPaused: true });
  assert.ok(report.blockers.length); assert.equal(report.applied, 0);
  assert.equal((await db.doc('matches/missing/joinRequests/requester').get()).data().email, 'legacy@example.com');
});

test('preparation projects membership, removes emails and markers, and establishes exact contribution baseline', async () => {
  const prepApp = initializeApp({ projectId: 'demo-padelx-preparation' }, 'preparation');
  const prep = getFirestore(prepApp);
  try {
    await prep.doc('publicProfiles/player').set({ ratingSum: 999 });
    await prep.doc('matches/past').set({ creatorUid: 'owner', players: [{ uid: 'player' }], spotsLeft: 2,
      scheduledAt: Timestamp.fromDate(new Date('2020-01-01')) });
    await prep.doc('matches/past/joinRequests/player').set({ email: 'legacy@example.com' });
    await prep.doc('matches/past/ratingRaters/owner/ratings/player').set({ matchId: 'past', raterUid: 'owner', ratedUid: 'player', rating: 4 });
    await prep.doc('ratingAggregationEvents/old').set({ processed: true });
    const dry = await prepareDeletion(prep);
    assert.deepEqual(dry.blockers, []); assert.equal(dry.applied, 0); assert.ok(dry.plannedWrites >= 5);
    assert.equal((await prep.doc('publicProfiles/player').get()).data().ratingSum, 999);
    const applied = await prepareDeletion(prep, { apply: true, writersPaused: true });
    assert.equal(applied.applied, dry.plannedWrites);
    assert.deepEqual((await prep.doc('matches/past').get()).data().participantUids, ['owner','player']);
    assert.equal((await prep.doc('publicProfiles/player').get()).data().ratingSum, 4);
    assert.equal('email' in (await prep.doc('matches/past/joinRequests/player').get()).data(), false);
    assert.equal((await prep.collection('ratingContributions').get()).size, 1);
    assert.equal((await prep.collection('ratingAggregationEvents').get()).size, 0);
    assert.equal((await prepareDeletion(prep)).plannedWrites, 0);
  } finally { await deleteApp(prepApp); }
});

test('combined deletion preserves all four match outcomes and exact surviving rating aggregate', async () => {
  const uid = 'all-effects', survivor = 'surviving-player';
  await auth.createUser({ uid });
  await db.doc(`publicProfiles/${survivor}`).set({ ratingCount: 2, ratingSum: 9, ratingAverage: 4.5 });
  const { ratingIdentity } = await import('../functions/rating_contributions.js');
  for (const organized of [true, false]) for (const past of [true, false]) {
    const id = `combined-${organized}-${past}`;
    await db.doc(`matches/${id}`).set({ creatorUid: organized ? uid : survivor,
      creatorEmail: organized ? 'old@example.com' : 'survivor@example.com',
      players: [{ uid: organized ? survivor : uid, displayName: 'Player', email: 'old@example.com' }],
      participantUids: organized ? [uid, survivor] : [survivor, uid], spotsLeft: 2,
      scheduledAt: Timestamp.fromMillis(Date.now() + (past ? -86400000 : 86400000)) });
  }
  const removed = 'matches/combined-true-true/ratingRaters/all-effects/ratings/surviving-player';
  const remaining = 'matches/unrelated/ratingRaters/other/ratings/surviving-player';
  await db.doc('matches/unrelated').set({ creatorUid: 'other', players: [{ uid: survivor }],
    participantUids: ['other', survivor], spotsLeft: 2, scheduledAt: Timestamp.fromMillis(Date.now()-86400000) });
  for (const [path, score] of [[removed, 4], [remaining, 5]]) {
    const { contributionId, ...identity } = ratingIdentity(path);
    await db.doc(path).set({ ...identity, rating: score });
    await db.doc(`ratingContributions/${contributionId}`).set({ ...identity, ratingPath: path, score, schemaVersion: 1 });
  }
  await db.doc('matches/combined-true-false/joinRequests/surviving-player').set({ userId: survivor });
  await db.doc('matches/unrelated/joinRequests/all-effects').set({ userId: uid });
  await db.doc('notifications/all-effects').set({ recipientUid: survivor, actorUid: uid, matchId: 'combined-true-false' });
  await admitAccountDeletion(db, auth, request(uid)); await finish(uid);
  const readMatch = async (organized, past) => (await db.doc(`matches/combined-${organized}-${past}`).get()).data();
  assert.equal((await readMatch(true, false)).status, 'cancelled');
  assert.deepEqual((await readMatch(true, true)).organizer, { deleted: true, displayName: 'Deleted player' });
  assert.deepEqual((await readMatch(false, false)).players, []);
  assert.deepEqual((await readMatch(false, true)).players, [{ deleted: true, displayName: 'Deleted player' }]);
  assert.equal((await db.doc(removed).get()).exists, false);
  assert.equal((await db.doc(remaining).get()).exists, true);
  assert.equal((await db.doc(`publicProfiles/${survivor}`).get()).data().ratingSum, 5);
  assert.equal((await db.doc(`publicProfiles/${survivor}`).get()).data().ratingCount, 1);
  assert.equal((await db.doc('notifications/all-effects').get()).exists, false);
  assert.equal((await db.doc('matches/unrelated/joinRequests/all-effects').get()).exists, false);
  assert.equal((await ref(uid).collection('matchCleanup').get()).size, 0);
  await assert.rejects(auth.getUser(uid), { code: 'auth/user-not-found' });
});

test('actual first-generation Auth deletion event creates the durable pipeline', async () => {
  const eventApp = initializeApp({ projectId: 'demo-padelx-phase8' }, 'auth-event');
  try {
    const eventAuth = getAuth(eventApp), eventDb = getFirestore(eventApp);
    const uid = 'actual-direct-auth-deletion';
    await eventAuth.createUser({ uid });
    await eventAuth.deleteUser(uid);
    for (let i = 0; i < 100; i++) {
      const job = await eventDb.doc(`accountDeletionJobs/${uid}`).get();
      if (job.exists) {
        assert.equal(job.data().uid, uid);
        assert.ok((await eventDb.doc(`accountDeletionBarriers/${uid}`).get()).exists);
        return;
      }
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    assert.fail('Auth deletion event did not create pipeline');
  } finally { await deleteApp(eventApp); }
});

test('eight retryable dispatch failures block without deleting Auth; future retries stay ineligible', async () => {
  const uid = 'exhausted'; await auth.createUser({ uid });
  await admitAccountDeletion(db, auth, request(uid));
  // Force an external retryable failure while retaining accepted checkpoint.
  await ref(uid).update({ authDisabledAt: null, authRevokedAt: null });
  const failingAuth = { updateUser: async () => { throw new Error('temporary failure'); } };
  for (let i = 0; i < 8; i++) {
    await db.doc(`accountDeletionOutbox/${uid}`).update({ nextAttemptAt: new Date(0) });
    await ref(uid).update({ nextAttemptAt: new Date(0) });
    await dispatchAccountDeletion(db, failingAuth, uid);
    if (i === 0) {
      const before = (await ref(uid).get()).data();
      assert.equal(await acquireDeletionLease(db, uid, { leaseOwner: 'early', leaseToken: 'early' }), false);
      assert.equal(before.status, 'retry_wait');
    }
  }
  const job = (await ref(uid).get()).data();
  assert.equal(job.status, 'blocked'); assert.equal(job.lastErrorCode, 'retry-exhausted');
  assert.equal(job.completedAt, null); assert.ok(await auth.getUser(uid));
  await recoverAccountDeletions(db, auth);
  assert.equal((await ref(uid).get()).data().status, 'blocked');
});

test('late lockdown delivery cannot revive an operator-blocked admission job', async () => {
  const uid = 'blocked-admission'; await acceptDeletedAuthUser(db, uid);
  await ref(uid).update({ status: 'blocked' });
  await lockDeletionAuth(db, { updateUser: () => assert.fail('blocked Auth effect') }, uid);
  assert.equal((await ref(uid).get()).data().status, 'blocked');
});
