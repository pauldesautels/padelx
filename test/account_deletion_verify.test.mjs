import { readFileSync } from 'node:fs';
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { deletionStateFor } from '../functions/account_state.js';
import { acquireDeletionLease, runVerifyDeletionPhase as run, DELETION_PHASE_COMPLETE_CHECKPOINT } from '../functions/account_deletion_worker.js';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-padelx-verification';
process.env.GCLOUD_PROJECT = projectId; process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'verification-tests');
const db = getFirestore(app); after(() => deleteApp(app));
const cutoff = Timestamp.fromDate(new Date('2026-01-01'));
const lease = { leaseOwner: 'join-worker', leaseToken: 'first' };
const jobRef = (uid) => db.doc(`accountDeletionJobs/${uid}`);
const anonymous = () => ({ deleted: true, displayName: 'Deleted player' });
const historical = () => ({ scheduledAt: cutoff, organizer: anonymous(), players: [], participantUids: [] });
async function seed(uid) {
  const state = deletionStateFor(uid, cutoff.toDate());
  await jobRef(uid).set({ ...state.job, phase: 'verify', authDisabledAt: cutoff, authRevokedAt: cutoff });
  await db.doc(`accountDeletionBarriers/${uid}`).set(state.barrier);
  await db.doc(`accountDeletionOutbox/${uid}`).set({ ...state.barrier, jobId: uid, status: 'ready_for_cleanup' });
  assert.equal(await acquireDeletionLease(db, uid, lease), true);
}
async function manifest(uid, matchId, extra = {}) {
  await jobRef(uid).collection('matchCleanup').doc(matchId).set({ matchId, organized: true, future: true, deletionRequestedAt: cutoff, ...extra });
}
async function finish(uid, active = lease, options) {
  for (let i = 0; i < 30; i++) {
    const result = await run(db, uid, active, options);
    assert.ok((result.processed ?? 0) <= (options?.pageSize ?? 100));
    if (result.complete) return;
  }
  assert.fail('did not finish');
}
async function blocked(uid, code) {
  const before = (await jobRef(uid).get()).data();
  await assert.rejects(run(db, uid, lease), /verification failed/);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.phase, 'verify'); assert.equal(job.status, 'blocked');
  assert.equal(job.lastErrorCode, code); assert.equal(job.checkpoint, before.checkpoint);
  assert.deepEqual(job.verifyCheckpoint, before.verifyCheckpoint);
  assert.ok(job.deletionRequestedAt.isEqual(before.deletionRequestedAt));
}
for (const collection of ['users', 'publicProfiles']) test(`${collection} profile blocks`, async () => {
  const uid = `profile-${collection}`; await seed(uid);
  await db.doc(`${collection}/${uid}`).set({ uid });
  await blocked(uid, 'verify-profile-remains'); assert.equal((await db.doc(`${collection}/${uid}`).get()).exists, true);
});
for (const field of ['creatorUid', 'createdBy', 'participantUids']) test(`residual match ${field} blocks`, async () => {
  const uid = `match-${field}`; await seed(uid);
  await db.doc(`matches/${uid}`).set({ scheduledAt: Timestamp.fromMillis(cutoff.toMillis() + 1000),
    [field]: field === 'participantUids' ? [uid] : uid });
  await blocked(uid, 'verify-match-reference');
});
for (const field of ['userId', 'uid']) test(`residual join request ${field} blocks`, async () => {
  const uid = `request-${field}`; await seed(uid);
  await db.doc(`matches/${uid}/joinRequests/${uid}`).set({ [field]: uid });
  await blocked(uid, 'verify-join-request-remains');
});
test('manifest discovers legacy path-only request without a parent', async () => {
  const uid = 'legacy-path'; await seed(uid); await manifest(uid, uid, { future: false });
  await db.doc(`matches/${uid}/joinRequests/${uid}`).set({ status: 'approved' });
  await blocked(uid, 'verify-join-request-remains');
});
for (const field of ['recipientUid', 'actorUid']) test(`residual notification ${field} blocks`, async () => {
  const uid = `notification-${field}`; await seed(uid);
  await db.doc(`notifications/${uid}`).set({ [field]: uid });
  await blocked(uid, 'verify-notification-remains');
});
for (const field of ['raterUid', 'ratedUid']) {
  test(`residual rating ${field} blocks`, async () => {
    const uid = `rating-${field}`; await seed(uid);
    await db.doc(`matches/${uid}/ratingRaters/other/ratings/other`).set({ [field]: uid });
    await blocked(uid, 'verify-rating-remains');
  });
  test(`orphan contribution ${field} blocks without a live rating`, async () => {
    const uid = `contribution-${field}`; await seed(uid);
    await db.doc(`ratingContributions/${uid}`).set({ [field]: uid });
    await blocked(uid, 'verify-contribution-remains');
  });
}
for (const collection of ['requests', 'notifications', 'ratings', 'contributions']) test(`cancelled manifest ${collection} blocks with missing match`, async () => {
  const uid = `cancelled-${collection}`; await seed(uid); await manifest(uid, uid);
  const paths = { requests: `matches/${uid}/joinRequests/other`, notifications: `notifications/${uid}`,
    ratings: `matches/${uid}/ratingRaters/other/ratings/survivor`, contributions: `ratingContributions/${uid}` };
  await db.doc(paths[collection]).set({ matchId: uid });
  const codes = { requests: 'request', notifications: 'notification', ratings: 'rating', contributions: 'contribution' };
  await blocked(uid, `verify-cancelled-match-${codes[collection]}`);
});
test('historical organizer and participant tombstones pass; unrelated data is ignored', async () => {
  const uid = 'historical-clean'; await seed(uid);
  await manifest(uid, `${uid}-owner`, { future: false });
  await db.doc(`matches/${uid}-owner`).set(historical());
  await manifest(uid, `${uid}-player`, { future: false, organized: false });
  await db.doc(`matches/${uid}-player`).set({ scheduledAt: cutoff, creatorUid: 'survivor',
    players: [anonymous(), { uid: 'other', displayName: 'Other', email: 'other@example.com', level: 4 }], participantUids: ['survivor', 'other'] });
  await db.doc(`notifications/${uid}`).set({ actorUid: 'other', recipientUid: 'survivor', actorDisplayName: uid });
  await run(db, uid, lease); assert.equal((await jobRef(uid).get()).data().phase, 'verify');
  await finish(uid);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.phase, 'deleteAuth'); assert.equal(job.checkpoint, null); assert.equal(job.completedAt, null);
  assert.equal(job.lastPhaseTransition.from, 'verify'); assert.equal(job.lastPhaseTransition.to, 'deleteAuth');
  assert.ok(job.deletionRequestedAt.isEqual(cutoff));
  await run(db, uid, lease); assert.deepEqual((await jobRef(uid).get()).data(), job);
  assert.equal((await db.doc(`notifications/${uid}`).get()).exists, true);
});
for (const field of ['uid', 'userId', 'email', 'displayName', 'level']) test(`historical deleted player retains ${field}: blocked`, async () => {
  const uid = `historical-player-${field}`; await seed(uid); await manifest(uid, uid, { organized: false, future: false });
  await db.doc(`matches/${uid}`).set({ scheduledAt: cutoff, creatorUid: 'survivor', participantUids: ['survivor'],
    players: [{ ...anonymous(), [field]: uid }] });
  await blocked(uid, 'verify-match-anonymization');
});
test('historical legacy player UID hidden from participant projection blocks', async () => {
  const uid = 'historical-hidden'; await seed(uid); await manifest(uid, uid, { organized: false, future: false });
  await db.doc(`matches/${uid}`).set({ scheduledAt: cutoff, creatorUid: 'survivor', participantUids: ['survivor'], players: [{ userId: uid }] });
  await blocked(uid, 'verify-match-anonymization');
});
for (const kind of ['organizer-snapshot', 'owner-snapshot', 'missing-slot', 'bad-manifest', 'not-cancelled']) test(`${kind} fails closed`, async () => {
  const uid = `bad-${kind}`; await seed(uid);
  await manifest(uid, uid, { future: kind === 'not-cancelled', organized: kind !== 'missing-slot', ...(kind === 'bad-manifest' ? { matchId: 'wrong' } : {}) });
  const data = historical();
  if (kind === 'organizer-snapshot') data.organizer.email = 'private@example.com';
  if (kind === 'owner-snapshot') data.creatorDisplayName = 'Private';
  if (kind === 'missing-slot') { data.creatorUid = 'survivor'; data.participantUids = ['survivor']; }
  if (kind === 'not-cancelled') data.scheduledAt = Timestamp.fromMillis(cutoff.toMillis() + 1000);
  await db.doc(`matches/${uid}`).set(data);
  await blocked(uid, kind === 'bad-manifest' ? 'verify-manifest' : 'verify-match-anonymization');
});
for (const kind of ['missing-barrier', 'barrier-uid', 'barrier-cutoff', 'job-schema', 'outbox-schema', 'auth-disable', 'auth-revoke', 'prior-block']) test(`${kind} infrastructure blocks`, async () => {
  const uid = `infra-${kind}`; await seed(uid);
  if (kind === 'missing-barrier') await db.doc(`accountDeletionBarriers/${uid}`).delete();
  if (kind === 'barrier-uid') await db.doc(`accountDeletionBarriers/${uid}`).update({ uid: 'wrong' });
  if (kind === 'barrier-cutoff') await db.doc(`accountDeletionBarriers/${uid}`).update({ deletionRequestedAt: Timestamp.fromMillis(1) });
  if (kind === 'job-schema') await jobRef(uid).update({ schemaVersion: 999 });
  if (kind === 'outbox-schema') await db.doc(`accountDeletionOutbox/${uid}`).update({ schemaVersion: 999 });
  if (kind === 'auth-disable') await jobRef(uid).update({ authDisabledAt: null });
  if (kind === 'auth-revoke') await jobRef(uid).update({ authRevokedAt: null });
  if (kind === 'prior-block') await jobRef(uid).update({ ratingsBlockedRecord: 'private-path' });
  await blocked(uid, 'verify-infrastructure');
});
test('manifest pagination resumes; all query reads have limit one; stale lease cannot complete', async () => {
  const uid = 'bounded'; await seed(uid);
  for (const id of ['bounded-a', 'bounded-b']) await manifest(uid, id);
  const limits = [];
  const checked = new Proxy(db, { get(object, key) {
    if (key === 'runTransaction') return (callback) => object.runTransaction((tx) => callback(new Proxy(tx, { get(transaction, member) {
      if (member === 'get') return (target) => {
        if (target._queryOptions) { limits.push(target._queryOptions.limit); assert.equal(target._queryOptions.limit, 1); }
        return transaction.get(target);
      };
      const value = Reflect.get(transaction, member, transaction); return typeof value === 'function' ? value.bind(transaction) : value;
    } })));
    const value = Reflect.get(object, key, object); return typeof value === 'function' ? value.bind(object) : value;
  } });
  assert.equal((await run(checked, uid, lease)).processed, 1);
  assert.ok(limits.length >= 12); assert.ok(limits.length <= 16);
  const before = (await jobRef(uid).get()).data(); assert.equal(before.verifyCheckpoint.manifestAfter, 'bounded-a');
  await jobRef(uid).update({ leaseExpiresAt: new Date(0) });
  const fresh = { ...lease, leaseToken: 'fresh' }; await acquireDeletionLease(db, uid, fresh);
  await assert.rejects(run(db, uid, lease), /lease lost/);
  assert.deepEqual((await jobRef(uid).get()).data().verifyCheckpoint, before.verifyCheckpoint);
  await finish(uid, fresh); assert.equal((await jobRef(uid).get()).data().phase, 'deleteAuth');
});
test('global references are rechecked after manifest progress and cutoff stays pinned', async () => {
  const uid = 'recheck'; await seed(uid); await manifest(uid, uid); await run(db, uid, lease);
  await db.doc(`notifications/${uid}`).set({ recipientUid: uid }); await blocked(uid, 'verify-notification-remains');
  const fixed = 'fixed'; await seed(fixed); await manifest(fixed, fixed); await run(db, fixed, lease);
  for (const collection of ['accountDeletionJobs', 'accountDeletionBarriers', 'accountDeletionOutbox']) await db.doc(`${collection}/${fixed}`).update({ deletionRequestedAt: Timestamp.fromMillis(1) });
  await blocked(fixed, 'verify-infrastructure');
});
test('completion marker recovery and clean state do not perform Auth deletion', async () => {
  const uid = 'recovery'; await seed(uid); await finish(uid);
  await jobRef(uid).update({ phase: 'verify', checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT });
  await run(db, uid, lease);
  assert.equal((await jobRef(uid).get()).data().phase, 'deleteAuth');
  assert.equal((await jobRef(uid).get()).data().completedAt, null);
});
test('legacy UID collection-group index exists', () => {
  const config = JSON.parse(readFileSync(new URL('../firestore.indexes.json', import.meta.url)));
  const index = config.fieldOverrides.find((entry) => entry.collectionGroup === 'joinRequests' && entry.fieldPath === 'uid');
  assert.ok(index.indexes.some((entry) => entry.queryScope === 'COLLECTION_GROUP' && entry.order === 'ASCENDING'));
});
test('final transition rechecks profiles after completion marker and blocks a late residual', async () => {
  const uid = 'final-recheck'; await seed(uid); let inject = true;
  const wrapped = new Proxy(db, { get(object, key) {
    if (key === 'runTransaction') return async (...args) => {
      const result = await object.runTransaction(...args);
      if (inject) { inject = false; await db.doc(`users/${uid}`).set({ uid }); }
      return result;
    };
    const value = Reflect.get(object, key, object); return typeof value === 'function' ? value.bind(object) : value;
  } });
  await assert.rejects(run(wrapped, uid, lease), /verification failed/);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.phase, 'verify'); assert.equal(job.status, 'blocked');
  assert.equal(job.lastErrorCode, 'verify-profile-remains');
});
test('malformed completion state cannot skip the manifest', async () => {
  const uid = 'bad-checkpoint'; await seed(uid);
  await jobRef(uid).update({ verifyCheckpoint: { manifestAfter: null, manifestDone: true } });
  await blocked(uid, 'verify-checkpoint');
});
test('lost page acknowledgement retains verification cursor and resumes with fresh lease', async () => {
  const uid = 'verify-lost-ack'; await seed(uid); await manifest(uid, uid); let lose = true;
  const flaky = new Proxy(db, { get(object, key) {
    if (key === 'runTransaction') return async (...args) => {
      const result = await object.runTransaction(...args);
      if (lose) { lose = false; throw Object.assign(new Error('private detail'), { code: 14 }); }
      return result;
    };
    const value = Reflect.get(object, key, object); return typeof value === 'function' ? value.bind(object) : value;
  } });
  await assert.rejects(run(flaky, uid, lease), /retry required/);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.status, 'retry_wait'); assert.equal(job.verifyCheckpoint.manifestAfter, uid);
  assert.equal(job.lastErrorCode, 'worker-work-failed');
  await jobRef(uid).update({ nextAttemptAt: new Date(0) });
  const fresh = { ...lease, leaseToken: 'retry' }; assert.equal(await acquireDeletionLease(db, uid, fresh), true);
  await finish(uid, fresh);
  assert.equal((await jobRef(uid).get()).data().phase, 'deleteAuth');
});
