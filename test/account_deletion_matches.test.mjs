import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { cleanDeletionMatch, DELETED_PLAYER } from '../functions/account_deletion_matches.js';
import { deletionStateFor } from '../functions/account_state.js';
import { acquireDeletionLease, runMatchesDeletionPhase, DELETION_PHASE_COMPLETE_CHECKPOINT } from '../functions/account_deletion_worker.js';
const cutoff = Timestamp.fromDate(new Date('2026-01-01'));
const match = (uid, past = false) => ({ creatorUid: 'owner', players: [{ uid, displayName: 'Private', email: 'private', level: '3' }],
  participantUids: ['owner', uid], spotsLeft: 2, scheduledAt: new Timestamp(cutoff.seconds + (past ? 0 : 1), 0), club: 'Venue', ratingSum: 9 });
for (const legacy of [false, true]) test(`organizer and participant semantics, legacy=${legacy}`, () => {
  for (const past of [false, true]) {
    const data = match('target', past);
    if (legacy) { data.players[0].userId = 'target'; delete data.players[0].uid; }
    const result = cleanDeletionMatch(data, 'target', cutoff).data;
    assert.deepEqual(result.participantUids, ['owner']);
    assert.equal(result.spotsLeft, past ? 2 : 3);
    assert.deepEqual(result.players, past ? [DELETED_PLAYER] : []);
    const owned = { ...data, creatorEmail: 'secret', creatorLevel: '4', creatorDisplayName: 'Private' };
    if (legacy) { owned.createdBy = 'owner'; delete owned.creatorUid; }
    const cleaned = cleanDeletionMatch(owned, 'owner', cutoff).data;
    assert.deepEqual(cleaned.organizer, DELETED_PLAYER);
    for (const field of ['creatorUid', 'createdBy', 'creatorEmail', 'creatorLevel', 'creatorDisplayName']) assert.equal(cleaned[field], undefined);
    assert.equal(cleaned.status, past ? undefined : 'cancelled');
    assert.deepEqual(cleaned.players, owned.players);
    assert.equal(cleaned.club, 'Venue'); assert.equal(cleaned.ratingSum, 9);
  }
});
test('ambiguous state is never guessed', () => {
  for (const patch of [{ scheduledAt: 'bad' }, { scheduledAt: null }, { createdBy: 'conflict' },
    { players: [{ email: 'target' }] }, { players: [{ uid: 'target', userId: 'other' }] },
    { participantUids: ['owner', 'wrong'] }, { spotsLeft: 3 }, { capacity: 9 }]) {
    assert.throws(() => cleanDeletionMatch({ ...match('target'), ...patch }, 'target', cutoff), /Ambiguous/);
  }
});
assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-padelx-matches';
process.env.GCLOUD_PROJECT = projectId; process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'matches-tests'); const db = getFirestore(app);
after(() => deleteApp(app));
const lease = { leaseOwner: 'matches-worker', leaseToken: 'first' };
const jobRef = (uid) => db.doc(`accountDeletionJobs/${uid}`);
async function seed(uid) {
  const state = deletionStateFor(uid, cutoff.toDate());
  await jobRef(uid).set({ ...state.job, phase: 'matches', authDisabledAt: cutoff, authRevokedAt: cutoff });
  await db.doc(`accountDeletionBarriers/${uid}`).set(state.barrier);
  await db.doc(`accountDeletionOutbox/${uid}`).set({ ...state.barrier, jobId: uid, status: 'ready_for_cleanup' });
  assert.equal(await acquireDeletionLease(db, uid, lease), true);
}
async function finish(uid, options) {
  for (let i = 0; i < 20; i++) if ((await runMatchesDeletionPhase(db, uid, lease, options)).complete) return;
  assert.fail('did not finish');
}
test('101 records page, resume with fresh lease, fence stale writes and finish only all streams', async () => {
  const uid = 'paged'; await seed(uid);
  const batch = db.batch();
  for (let i = 0; i < 101; i++) batch.set(db.doc(`matches/paged-${String(i).padStart(3, '0')}`), {
    ...match('guest'), creatorUid: uid, participantUids: [uid, 'guest'] });
  batch.set(db.doc('matches/paged-legacy'), { ...match('guest'), creatorUid: '', createdBy: uid, participantUids: [uid, 'guest'] });
  batch.set(db.doc('matches/paged-participant'), match(uid));
  batch.set(db.doc('matches/email-only'), { ...match('someone'), creatorEmail: uid });
  await batch.commit();
  assert.equal((await runMatchesDeletionPhase(db, uid, lease)).processed, 100);
  const prior = (await jobRef(uid).get()).data();
  assert.equal(prior.matchesCheckpoint.creatorUid.after, 'paged-099'); assert.equal(prior.phase, 'matches');
  await jobRef(uid).update({ leaseExpiresAt: new Date(0) });
  const fresh = { ...lease, leaseToken: 'fresh' }; await acquireDeletionLease(db, uid, fresh);
  await assert.rejects(runMatchesDeletionPhase(db, uid, lease), /lease lost/);
  assert.equal((await jobRef(uid).get()).data().checkpoint, prior.checkpoint);
  let result;
  do { result = await runMatchesDeletionPhase(db, uid, fresh); assert.ok((result.processed ?? 0) <= 100); } while (!result.complete);
  const done = (await jobRef(uid).get()).data();
  assert.equal(done.phase, 'joinRequests'); assert.equal(done.checkpoint, null);
  assert.ok(done.deletionRequestedAt.isEqual(cutoff));
  assert.equal(done.lastPhaseTransition.from, 'matches');
  assert.equal((await jobRef(uid).collection('matchCleanup').get()).size, 103);
  const participant = (await db.doc('matches/paged-participant').get()).data();
  assert.equal(participant.spotsLeft, 3);
  await runMatchesDeletionPhase(db, uid, fresh);
  assert.deepEqual((await db.doc('matches/paged-participant').get()).data(), participant);
  assert.equal((await db.doc('matches/email-only').get()).data().creatorEmail, uid);
});
test('malformed page blocks atomically without checkpoint or match effects', async () => {
  const uid = 'bad-page'; await seed(uid);
  await db.doc('matches/bad-page-a').set(match(uid));
  await db.doc('matches/bad-page-b').set({ ...match(uid), scheduledAt: 'bad' });
  await runMatchesDeletionPhase(db, uid, lease); await runMatchesDeletionPhase(db, uid, lease);
  const before = (await jobRef(uid).get()).data();
  await assert.rejects(runMatchesDeletionPhase(db, uid, lease), /blocked/);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.status, 'blocked'); assert.equal(job.checkpoint, before.checkpoint);
  assert.equal(job.phase, 'matches'); assert.equal(job.matchesBlockedRecord, 'bad-page-b');
  assert.equal((await db.doc('matches/bad-page-a').get()).data().spotsLeft, 2);
});
test('past participant placeholder and completion marker resume', async () => {
  const uid = 'historical'; await seed(uid);
  await db.doc('matches/historical').set(match(uid, true));
  await finish(uid, { pageSize: 1 });
  assert.deepEqual((await db.doc('matches/historical').get()).data().players, [DELETED_PLAYER]);
  await jobRef(uid).update({ phase: 'matches', checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT });
  await runMatchesDeletionPhase(db, uid, lease);
  assert.equal((await jobRef(uid).get()).data().phase, 'joinRequests');
});
test('cutoff changes between pages and invalid bounds fail closed', async () => {
  const uid = 'cutoff'; await seed(uid);
  for (const pageSize of [0, 101, 1.5]) await assert.rejects(runMatchesDeletionPhase(db, uid, lease, { pageSize }));
  await runMatchesDeletionPhase(db, uid, lease);
  for (const collection of ['accountDeletionJobs', 'accountDeletionBarriers', 'accountDeletionOutbox']) {
    await db.doc(`${collection}/${uid}`).update({ deletionRequestedAt: Timestamp.fromMillis(1) });
  }
  await assert.rejects(runMatchesDeletionPhase(db, uid, lease), /checkpoint/);
});
test('missing legacy organizer projection is rebuilt and timestamp comparison preserves nanoseconds', () => {
  const data = { ...match('guest'), createdBy: 'owner', creatorUid: '' };
  delete data.participantUids;
  assert.deepEqual(cleanDeletionMatch(data, 'owner', cutoff).data.participantUids, ['guest']);
  const exact = { ...match('target'), scheduledAt: new Timestamp(cutoff.seconds, 1) };
  assert.equal(cleanDeletionMatch(exact, 'target', cutoff).future, true);
  assert.equal(cleanDeletionMatch({ ...exact, scheduledAt: cutoff }, 'target', cutoff).future, false);
});
test('unsafe environment and wrong owner cannot reach match writes', async () => {
  const unsafe = { projectId: 'padelx-f168f', collection: () => assert.fail('production access') };
  await assert.rejects(runMatchesDeletionPhase(unsafe, 'uid', lease), /trusted runtime/);
  const uid = 'wrong-owner'; await seed(uid);
  await db.doc('matches/wrong-owner').set(match(uid));
  await assert.rejects(runMatchesDeletionPhase(db, uid, { ...lease, leaseOwner: 'wrong' }), /lease lost/);
  assert.equal((await jobRef(uid).get()).data().checkpoint, null);
  assert.equal((await db.doc('matches/wrong-owner').get()).data().spotsLeft, 2);
});
