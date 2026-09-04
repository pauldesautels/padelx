import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { deletionStateFor } from '../functions/account_state.js';
import { acquireDeletionLease, runJoinRequestsDeletionPhase as run, DELETION_PHASE_COMPLETE_CHECKPOINT } from '../functions/account_deletion_worker.js';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-padelx-join-requests';
process.env.GCLOUD_PROJECT = projectId; process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'join-request-tests');
const db = getFirestore(app); after(() => deleteApp(app));
const cutoff = Timestamp.fromDate(new Date('2026-01-01'));
const lease = { leaseOwner: 'join-worker', leaseToken: 'first' };
const jobRef = (uid) => db.doc(`accountDeletionJobs/${uid}`);
const request = (match, uid) => db.doc(`matches/${match}/joinRequests/${uid}`);
async function seed(uid) {
  const state = deletionStateFor(uid, cutoff.toDate());
  await jobRef(uid).set({ ...state.job, phase: 'joinRequests', authDisabledAt: cutoff, authRevokedAt: cutoff });
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
test('all statuses, matching UID fields, orphan parents and email-only exclusion', async () => {
  const uid = 'statuses'; await seed(uid);
  for (const status of ['pending', 'approved', 'declined', 'rejected']) await request(`statuses-${status}`, uid).set({ userId: uid, uid, status, email: 'private' });
  await request('email-only', 'unrelated').set({ email: uid });
  await finish(uid);
  for (const status of ['pending', 'approved', 'declined', 'rejected']) assert.equal((await request(`statuses-${status}`, uid).get()).exists, false);
  assert.equal((await request('email-only', 'unrelated').get()).exists, true);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.phase, 'notifications'); assert.equal(job.checkpoint, null);
  assert.equal(job.lastPhaseTransition.from, 'joinRequests'); assert.equal(job.lastPhaseTransition.to, 'notifications');
  assert.ok(job.deletionRequestedAt.isEqual(cutoff));
  await run(db, uid, lease);
});
test('101 owned requests resume stable full paths and fence an expired worker', async () => {
  const uid = 'pagination'; await seed(uid);
  const batch = db.batch();
  for (let i = 0; i < 101; i++) batch.set(request(`pagination-${String(i).padStart(3, '0')}`, uid), { userId: uid });
  await batch.commit();
  assert.equal((await run(db, uid, lease)).processed, 100);
  const before = (await jobRef(uid).get()).data();
  assert.equal(before.joinRequestsCheckpoint.userAfter, `matches/pagination-099/joinRequests/${uid}`);
  assert.equal(before.phase, 'joinRequests');
  await jobRef(uid).update({ leaseExpiresAt: new Date(0) });
  const fresh = { ...lease, leaseToken: 'fresh' }; await acquireDeletionLease(db, uid, fresh);
  await assert.rejects(run(db, uid, lease), /lease lost/);
  assert.equal((await request('pagination-100', uid).get()).exists, true);
  assert.equal((await jobRef(uid).get()).data().checkpoint, before.checkpoint);
  await finish(uid, fresh);
  assert.equal((await request('pagination-100', uid).get()).exists, false);
});
test('manifest pages all descendants, preserves unrelated matches, and supports path-only legacy ownership', async () => {
  const uid = 'manifest'; await seed(uid);
  for (const matchId of ['manifest-a', 'manifest-b']) {
    await manifest(uid, matchId);
    const batch = db.batch();
    for (let i = 0; i < 101; i++) batch.set(request(matchId, `guest-${String(i).padStart(3, '0')}`), { status: 'approved', email: 'private' });
    await batch.commit();
  }
  await manifest(uid, 'manifest-past', { future: false });
  await request('manifest-past', uid).set({ uid, status: 'declined' });
  await request('manifest-past', 'other').set({ userId: 'other' });
  await request('manifest-unlisted', 'other').set({ userId: 'other' });
  await run(db, uid, lease); // owned stream empty
  assert.equal((await run(db, uid, lease)).processed, 100);
  const checkpoint = (await jobRef(uid).get()).data().joinRequestsCheckpoint;
  assert.equal(checkpoint.manifestAfter, null); assert.equal(checkpoint.requestAfter, 'guest-099');
  await finish(uid);
  for (const matchId of ['manifest-a', 'manifest-b']) assert.equal((await db.collection(`matches/${matchId}/joinRequests`).get()).size, 0);
  assert.equal((await request('manifest-past', uid).get()).exists, false);
  assert.equal((await request('manifest-past', 'other').get()).exists, true);
  assert.equal((await request('manifest-unlisted', 'other').get()).exists, true);
  // Replay completed cleanup from an earlier durable position.
  await jobRef(uid).update({ phase: 'joinRequests', checkpoint: 0, joinRequestsCheckpoint: {
    userAfter: null, userDone: false, manifestAfter: null, manifestDone: false, requestAfter: null,
  } });
  await finish(uid, lease, { pageSize: 1 });
});
for (const kind of ['path', 'uid', 'manifest', 'bad-manifest']) test(`ambiguity ${kind} preserves page and blocks completion`, async () => {
  const uid = `bad-${kind}`; await seed(uid);
  let bad;
  if (kind === 'manifest' || kind === 'bad-manifest') {
    await manifest(uid, uid, kind === 'bad-manifest' ? { matchId: 'wrong' } : {});
    await request(uid, 'a').set({ userId: 'a' });
    bad = request(uid, 'b'); await bad.set({ userId: 'conflict' });
    await run(db, uid, lease);
  } else {
    await request(`${uid}-a`, uid).set({ userId: uid });
    bad = request(`${uid}-b`, kind === 'path' ? 'other' : uid);
    await bad.set({ userId: uid, ...(kind === 'uid' ? { uid: 'other' } : {}) });
  }
  const before = (await jobRef(uid).get()).data();
  await assert.rejects(run(db, uid, lease), /blocked/);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.status, 'blocked'); assert.equal(job.phase, 'joinRequests');
  assert.equal(job.checkpoint, before.checkpoint); assert.equal((await bad.get()).exists, true);
  assert.equal((await request(kind.startsWith('manifest') || kind === 'bad-manifest' ? uid : `${uid}-a`, kind.startsWith('manifest') || kind === 'bad-manifest' ? 'a' : uid).get()).exists, true);
});
test('bounds, fixed cutoff, incomplete streams and completion-marker recovery', async () => {
  const uid = 'fixed'; await seed(uid);
  for (const pageSize of [0, 101, 1.5]) await assert.rejects(run(db, uid, lease, { pageSize }));
  await run(db, uid, lease);
  assert.equal((await jobRef(uid).get()).data().phase, 'joinRequests');
  for (const collection of ['accountDeletionJobs', 'accountDeletionBarriers', 'accountDeletionOutbox']) await db.doc(`${collection}/${uid}`).update({ deletionRequestedAt: Timestamp.fromMillis(1) });
  await assert.rejects(run(db, uid, lease), /Invalid/);
  const recovery = 'recovery'; await seed(recovery); await finish(recovery);
  await jobRef(recovery).update({ phase: 'joinRequests', checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT });
  await run(db, recovery, lease);
  assert.equal((await jobRef(recovery).get()).data().phase, 'notifications');
});
test('join-request serialization excludes email while legacy reading remains compatible', () => {
  const source = readFileSync(new URL('../lib/main.dart', import.meta.url), 'utf8').split('class JoinRequest {')[1].split('enum AppNotificationType')[0];
  assert.doesNotMatch(source.split('Map<String, dynamic> toMap() =>')[1], /email/);
  assert.match(source, /email: data\['email'\]/);
});
