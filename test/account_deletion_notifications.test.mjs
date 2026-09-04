import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { deletionStateFor } from '../functions/account_state.js';
import { acquireDeletionLease, runNotificationsDeletionPhase as run, DELETION_PHASE_COMPLETE_CHECKPOINT } from '../functions/account_deletion_worker.js';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-padelx-notifications';
process.env.GCLOUD_PROJECT = projectId; process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'notification-tests');
const db = getFirestore(app); after(() => deleteApp(app));
const cutoff = Timestamp.fromDate(new Date('2026-01-01'));
const lease = { leaseOwner: 'join-worker', leaseToken: 'first' };
const jobRef = (uid) => db.doc(`accountDeletionJobs/${uid}`);
const notification = (id) => db.doc(`notifications/${id}`);
const data = (recipientUid, extra = {}) => ({ recipientUid, matchId: 'unlisted', ...extra });
async function seed(uid) {
  const state = deletionStateFor(uid, cutoff.toDate());
  await jobRef(uid).set({ ...state.job, phase: 'notifications', authDisabledAt: cutoff, authRevokedAt: cutoff });
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
test('recipient and actor deletion, legacy absence, snapshots and unrelated preservation', async () => {
  const uid = 'identity'; await seed(uid);
  await notification('identity-received').set(data(uid));
  await notification('identity-actor').set(data('other', { actorUid: uid, actorDisplayName: 'Private', message: 'Private requested' }));
  await notification('identity-name').set(data('other', { actorDisplayName: uid, message: uid, email: uid }));
  await notification('identity-other').set(data('other', { actorUid: 'someone' }));
  await notification('join_request_unlisted_identity-event').set(data('other', { actorUid: uid, type: 'join_request', eventId: 'identity-event' }));
  await run(db, uid, lease);
  assert.equal((await jobRef(uid).get()).data().phase, 'notifications');
  assert.equal((await notification('identity-actor').get()).exists, true);
  await finish(uid);
  for (const id of ['identity-received', 'identity-actor', 'join_request_unlisted_identity-event']) assert.equal((await notification(id).get()).exists, false);
  for (const id of ['identity-name', 'identity-other']) assert.equal((await notification(id).get()).exists, true);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.phase, 'ratings'); assert.equal(job.checkpoint, null);
  assert.equal(job.lastPhaseTransition.from, 'notifications'); assert.equal(job.lastPhaseTransition.to, 'ratings');
  assert.ok(job.deletionRequestedAt.isEqual(cutoff)); assert.equal(job.completedAt, null);
  await jobRef(uid).update({ checkpoint: 7 });
  await run(db, uid, lease);
  assert.equal((await jobRef(uid).get()).data().checkpoint, 7);
});
for (const stream of ['recipient', 'actor']) test(`${stream}: 101 records, durable resume and stale lease fencing`, async () => {
  const uid = `pages-${stream}`; await seed(uid);
  const batch = db.batch();
  for (let i = 0; i < 101; i++) batch.set(notification(`${uid}-${String(i).padStart(3, '0')}`), data(stream === 'recipient' ? uid : 'other', { actorUid: stream === 'actor' ? uid : 'other' }));
  await batch.commit();
  if (stream === 'actor') await run(db, uid, lease);
  assert.equal((await run(db, uid, lease)).processed, 100);
  const before = (await jobRef(uid).get()).data();
  assert.equal(before.notificationsCheckpoint[`${stream}After`], `${uid}-099`);
  assert.equal(before.notificationsCheckpoint[`${stream}Done`], false);
  assert.equal(before.phase, 'notifications');
  await jobRef(uid).update({ leaseExpiresAt: new Date(0) });
  const fresh = { ...lease, leaseToken: 'fresh' }; assert.equal(await acquireDeletionLease(db, uid, fresh), true);
  await assert.rejects(run(db, uid, lease), /lease lost/);
  assert.equal((await notification(`${uid}-100`).get()).exists, true);
  assert.deepEqual((await jobRef(uid).get()).data().notificationsCheckpoint, before.notificationsCheckpoint);
  await finish(uid, fresh);
  assert.equal((await notification(`${uid}-100`).get()).exists, false);
});
test('bounded manifest drains cancelled future matches without reading parents; replay is idempotent', async () => {
  const uid = 'manifest-notifications'; await seed(uid);
  for (const match of ['manifest-a', 'manifest-b']) {
    await manifest(uid, match);
    const batch = db.batch();
    for (let i = 0; i < 101; i++) batch.set(notification(`${match}-${String(i).padStart(3, '0')}`), data('other', { matchId: match }));
    await batch.commit();
  }
  await db.doc('matches/manifest-b').set({ status: 'cancelled' });
  await db.doc('matches/manifest-b').delete();
  for (const [match, extra] of [['past', { future: false }], ['participant', { organized: false }]]) {
    await manifest(uid, match, extra); await notification(`manifest-${match}`).set(data('other', { matchId: match }));
  }
  await notification('manifest-unrelated').set(data('other'));
  await run(db, uid, lease); await run(db, uid, lease);
  assert.equal((await run(db, uid, lease)).processed, 100);
  const before = (await jobRef(uid).get()).data();
  assert.equal(before.notificationsCheckpoint.manifestAfter, null);
  assert.equal(before.notificationsCheckpoint.matchAfter, 'manifest-a-099');
  assert.equal(before.phase, 'notifications');
  await finish(uid);
  for (const match of ['manifest-a', 'manifest-b']) assert.equal((await db.collection('notifications').where('matchId', '==', match).get()).size, 0);
  for (const id of ['manifest-past', 'manifest-participant', 'manifest-unrelated']) assert.equal((await notification(id).get()).exists, true);
  await jobRef(uid).update({ phase: 'notifications', checkpoint: 0, notificationsCheckpoint: {
    recipientAfter: null, recipientDone: false, actorAfter: null, actorDone: false,
    manifestAfter: null, manifestDone: false, matchAfter: null,
  } });
  await finish(uid, lease, { pageSize: 1 });
});
for (const kind of ['reference', 'actor', 'manifest']) test(`${kind} ambiguity preserves entire page and blocks`, async () => {
  const uid = `ambiguous-${kind}`; await seed(uid);
  const good = notification(`${uid}-a`), bad = notification(`${uid}-b`);
  await good.set(data(uid));
  if (kind === 'manifest') {
    await manifest(uid, uid, { matchId: 'conflict' });
    await run(db, uid, lease); await run(db, uid, lease);
  } else await bad.set(data(uid, kind === 'actor' ? { actorUid: { uid } } : { type: 'join_request', eventId: 'conflicting-reference' }));
  const before = (await jobRef(uid).get()).data();
  await assert.rejects(run(db, uid, lease), /blocked/);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.status, 'blocked'); assert.equal(job.phase, 'notifications');
  assert.equal(job.checkpoint, before.checkpoint);
  assert.deepEqual(job.notificationsCheckpoint, before.notificationsCheckpoint);
  if (kind !== 'manifest') { assert.equal((await good.get()).exists, true); assert.equal((await bad.get()).exists, true); }
  await assert.rejects(run(db, uid, lease), /Invalid/);
});
test('bounds, fixed cutoff and completion marker recovery', async () => {
  const uid = 'notification-fixed'; await seed(uid);
  for (const pageSize of [0, 101, 1.5]) await assert.rejects(run(db, uid, lease, { pageSize }));
  await run(db, uid, lease);
  assert.equal((await jobRef(uid).get()).data().phase, 'notifications');
  for (const collection of ['accountDeletionJobs', 'accountDeletionBarriers', 'accountDeletionOutbox']) await db.doc(`${collection}/${uid}`).update({ deletionRequestedAt: Timestamp.fromMillis(1) });
  await assert.rejects(run(db, uid, lease), /Invalid/);
  const recovery = 'notification-recovery'; await seed(recovery); await finish(recovery);
  await jobRef(recovery).update({ phase: 'notifications', checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT });
  await run(db, recovery, lease);
  assert.equal((await jobRef(recovery).get()).data().phase, 'ratings');
});
test('lost page acknowledgement retains durable effects and resumes with a fresh lease', async () => {
  const uid = 'notification-lost-ack'; await seed(uid);
  await notification(`${uid}-a`).set(data(uid));
  await notification(`${uid}-b`).set(data(uid));
  let loseResponse = true;
  const flaky = new Proxy(db, { get(target, key) {
    if (key === 'runTransaction') return async (...args) => {
      const result = await target.runTransaction(...args);
      if (loseResponse) { loseResponse = false; throw Object.assign(new Error('private detail'), { code: 14 }); }
      return result;
    };
    const value = Reflect.get(target, key, target);
    return typeof value === 'function' ? value.bind(target) : value;
  } });
  await assert.rejects(run(flaky, uid, lease, { pageSize: 1 }), /Notification cleanup failed/);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.status, 'retry_wait'); assert.equal(job.lastErrorCode, 'worker-work-failed');
  assert.equal(job.notificationsCheckpoint.recipientAfter, `${uid}-a`);
  assert.equal((await notification(`${uid}-a`).get()).exists, false);
  assert.equal((await notification(`${uid}-b`).get()).exists, true);
  await jobRef(uid).update({ nextAttemptAt: new Date(0) });
  const fresh = { ...lease, leaseToken: 'ack-retry' };
  assert.equal(await acquireDeletionLease(db, uid, fresh), true);
  await finish(uid, fresh, { pageSize: 1 });
  assert.equal((await notification(`${uid}-b`).get()).exists, false);
  assert.ok((await jobRef(uid).get()).data().deletionRequestedAt.isEqual(cutoff));
});
