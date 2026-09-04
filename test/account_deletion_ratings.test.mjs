import { ratingIdentity, reconcileRating } from '../functions/rating_contributions.js';
import { handlePlayerRatingWritten } from '../functions/index.js';
import { readFileSync } from 'node:fs';
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { deletionStateFor } from '../functions/account_state.js';
import { acquireDeletionLease, runRatingsDeletionPhase as run, DELETION_PHASE_COMPLETE_CHECKPOINT } from '../functions/account_deletion_worker.js';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-padelx-ratings';
process.env.GCLOUD_PROJECT = projectId; process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'rating-deletion-tests');
const db = getFirestore(app); after(() => deleteApp(app));
const cutoff = Timestamp.fromDate(new Date('2026-01-01'));
const lease = { leaseOwner: 'join-worker', leaseToken: 'first' };
const jobRef = (uid) => db.doc(`accountDeletionJobs/${uid}`);
const rating = (match, rater, rated) => db.doc(`matches/${match}/ratingRaters/${rater}/ratings/${rated}`);
const contribution = (ref) => db.doc(`ratingContributions/${ratingIdentity(ref.path).contributionId}`);
const profile = (uid) => db.doc(`publicProfiles/${uid}`);
async function totals(uid) {
  const data = (await profile(uid).get()).data();
  return data && [data.ratingCount, data.ratingSum, data.ratingAverage];
}
async function live(matchId, raterUid, ratedUid, score = 5) {
  const ref = rating(matchId, raterUid, ratedUid);
  if (!(await profile(ratedUid).get()).exists) await profile(ratedUid).set({ uid: ratedUid });
  await db.doc(`matches/${matchId}`).set({ creatorUid: raterUid, players: [{ uid: ratedUid }], scheduledAt: cutoff, status: 'open' });
  await ref.set({ matchId, raterUid, ratedUid, rating: score });
  await reconcileRating(db, ref.path);
  return ref;
}
async function seed(uid) {
  const state = deletionStateFor(uid, cutoff.toDate());
  await jobRef(uid).set({ ...state.job, phase: 'ratings', authDisabledAt: cutoff, authRevokedAt: cutoff });
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
test('given rating removes exactly its contribution; unrelated lifetime rating survives and delayed events cannot restore it', async () => {
  const uid = 'given', target = 'given-target';
  const own = await live('given-a', uid, target, 5);
  const other = await live('given-b', 'other-giver', target, 3);
  assert.deepEqual(await totals(target), [2, 8, 4]);
  await seed(uid);
  await run(db, uid, lease);
  assert.equal((await jobRef(uid).get()).data().phase, 'ratings');
  assert.deepEqual(await totals(target), [1, 3, 3]);
  assert.equal((await own.get()).exists, false); assert.equal((await contribution(own).get()).exists, false);
  assert.equal((await other.get()).exists, true); assert.equal((await contribution(other).get()).data().score, 3);
  await finish(uid);
  await Promise.all([reconcileRating(db, own.path), reconcileRating(db, own.path),
    handlePlayerRatingWritten({ params: { matchId: 'given-a', raterUid: uid, ratedUid: target }, data: { after: { data: () => ({ rating: 5 }) } } })]);
  assert.deepEqual(await totals(target), [1, 3, 3]);
  assert.equal((await contribution(own).get()).exists, false);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.phase, 'verify'); assert.equal(job.checkpoint, null);
  assert.equal(job.lastPhaseTransition.from, 'ratings'); assert.equal(job.lastPhaseTransition.to, 'verify');
  assert.ok(job.deletionRequestedAt.isEqual(cutoff)); assert.equal(job.completedAt, null);
  await jobRef(uid).update({ checkpoint: 7 }); await run(db, uid, lease);
  assert.equal((await jobRef(uid).get()).data().checkpoint, 7);
});
test('received ratings remove contributions without recreating missing profile; self-rating and stream overlap are harmless', async () => {
  const uid = 'received';
  const first = await live('received-a', 'received-giver-a', uid, 4);
  const second = await live('received-b', 'received-giver-b', uid, 2);
  await profile(uid).delete(); await seed(uid);
  const self = rating('received-self', uid, uid);
  await self.set({ matchId: 'received-self', raterUid: uid, ratedUid: uid, rating: 5 });
  await finish(uid);
  for (const ref of [first, second, self]) {
    assert.equal((await ref.get()).exists, false); assert.equal((await contribution(ref).get()).exists, false);
    await reconcileRating(db, ref.path);
  }
  assert.equal((await profile(uid).get()).exists, false);
});
test('multiple same-recipient ratings in one page normalize to zero', async () => {
  const uid = 'multi', target = 'multi-target';
  await live('multi-a', uid, target, 5); await live('multi-b', uid, target, 2);
  assert.deepEqual(await totals(target), [2, 7, 3.5]); await seed(uid); await finish(uid);
  assert.deepEqual(await totals(target), [0, 0, 0]);
});
test('simultaneous deleting users and trigger reconciliation converge on shared aggregate', async () => {
  const target = 'simultaneous-target';
  const a = await live('simultaneous-a', 'simultaneous-a', target, 5);
  const b = await live('simultaneous-b', 'simultaneous-b', target, 4);
  await seed('simultaneous-a'); await seed('simultaneous-b');
  await Promise.all([finish('simultaneous-a'), finish('simultaneous-b'), reconcileRating(db, a.path), reconcileRating(db, b.path)]);
  assert.deepEqual(await totals(target), [0, 0, 0]);
  for (const ref of [a, b]) { assert.equal((await ref.get()).exists, false); assert.equal((await contribution(ref).get()).exists, false); }
});
test('manifest drains only cancelled future organized ratings, including missing parents', async () => {
  const uid = 'cancelled', target = 'cancelled-target';
  const cancelled = await live('cancelled-a', 'cancelled-giver', target, 5);
  const missing = await live('cancelled-b', 'cancelled-giver', target, 4);
  const past = await live('cancelled-past', 'cancelled-giver', target, 3);
  await seed(uid);
  await db.doc('matches/cancelled-a').update({ status: 'cancelled' });
  await db.doc('matches/cancelled-b').delete();
  await manifest(uid, 'cancelled-a'); await manifest(uid, 'cancelled-b');
  await manifest(uid, 'cancelled-past', { future: false });
  await run(db, uid, lease); await run(db, uid, lease);
  assert.equal((await jobRef(uid).get()).data().phase, 'ratings');
  await finish(uid, lease, { pageSize: 1 });
  assert.deepEqual(await totals(target), [1, 3, 3]);
  for (const ref of [cancelled, missing]) { assert.equal((await ref.get()).exists, false); assert.equal((await contribution(ref).get()).exists, false); }
  assert.equal((await past.get()).exists, true);
  assert.equal((await contribution(past).get()).data().score, 3);
});
for (const stream of ['given', 'received', 'manifest']) test(`${stream}: 101 ratings paginate by full path and fresh lease resumes`, async () => {
  const uid = `pages-${stream}`, target = stream === 'received' ? uid : `${uid}-target`;
  const refs = []; const batch = db.batch();
  for (let i = 0; i < 101; i++) {
    const matchId = stream === 'manifest' ? uid : `${uid}-${String(i).padStart(3, '0')}`;
    const raterUid = stream === 'given' ? uid : `${uid}-rater-${String(i).padStart(3, '0')}`;
    const ref = rating(matchId, raterUid, target); refs.push(ref);
    batch.set(ref, { matchId, raterUid, ratedUid: target, rating: 4 });
    batch.set(contribution(ref), { schemaVersion: 1, ratingPath: ref.path, matchId, raterUid, ratedUid: target, score: 4 });
  }
  batch.set(profile(target), { ratingCount: 101, ratingSum: 404, ratingAverage: 4 }); await batch.commit();
  await seed(uid);
  if (stream !== 'given') await run(db, uid, lease);
  if (stream === 'manifest') { await manifest(uid, uid); await run(db, uid, lease); }
  assert.equal((await run(db, uid, lease)).processed, 100);
  const before = (await jobRef(uid).get()).data();
  assert.equal(before.ratingsCheckpoint[stream === 'manifest' ? 'matchAfter' : `${stream}After`], refs[99].path);
  assert.equal(before.phase, 'ratings'); assert.deepEqual(await totals(target), [1, 4, 4]);
  if (stream === 'manifest') assert.equal(before.ratingsCheckpoint.manifestAfter, null);
  await jobRef(uid).update({ leaseExpiresAt: new Date(0) });
  const fresh = { ...lease, leaseToken: 'fresh' }; assert.equal(await acquireDeletionLease(db, uid, fresh), true);
  await assert.rejects(run(db, uid, lease), /lease lost/);
  assert.equal((await refs[100].get()).exists, true);
  assert.deepEqual((await jobRef(uid).get()).data().ratingsCheckpoint, before.ratingsCheckpoint);
  await finish(uid, fresh); assert.deepEqual(await totals(target), [0, 0, 0]);
  for (const ref of refs) assert.equal((await contribution(ref).get()).exists, false);
});
for (const kind of ['matchId', 'raterUid', 'ratedUid', 'path', 'contribution', 'aggregate', 'manifest']) test(`${kind} ambiguity preserves page and blocks without negative totals`, async () => {
  const uid = `bad-${kind}`, target = `${uid}-target`;
  const good = await live(`${uid}-a`, uid, target, 5);
  let bad = await live(`${uid}-b`, uid, target, 3);
  await seed(uid);
  if (kind === 'path') {
    bad = db.doc(`invalid/${uid}/ratings/${target}`); await bad.set({ matchId: uid, raterUid: uid, ratedUid: target, rating: 1 });
  } else if (kind === 'contribution') await contribution(bad).update({ ratedUid: 'conflict' });
  else if (kind === 'aggregate') await profile(target).update({ ratingCount: 0, ratingSum: 0 });
  else if (kind === 'manifest') {
    await manifest(uid, uid, { matchId: 'conflict' }); await run(db, uid, lease); await run(db, uid, lease);
  } else {
    await bad.update({ [kind]: 'conflict' });
    // A wrong rater field is discovered through the received stream instead.
    if (kind === 'raterUid') {
      await bad.update({ ratedUid: uid });
      await run(db, uid, lease);
    }
  }
  const before = (await jobRef(uid).get()).data(); const aggregateBefore = await totals(target);
  await assert.rejects(run(db, uid, lease), /blocked/);
  const job = (await jobRef(uid).get()).data();
  assert.equal(job.status, 'blocked'); assert.equal(job.phase, 'ratings');
  assert.equal(job.checkpoint, before.checkpoint); assert.deepEqual(job.ratingsCheckpoint, before.ratingsCheckpoint);
  assert.deepEqual(await totals(target), aggregateBefore);
  if (!['manifest', 'raterUid'].includes(kind)) assert.equal((await good.get()).exists, true);
  if (kind !== 'manifest') assert.equal((await bad.get()).exists, true);
});
test('fixed cutoff, bounds, incomplete marker rejection and completion-marker recovery', async () => {
  const uid = 'fixed-ratings'; await seed(uid);
  for (const pageSize of [0, 101, 1.5]) await assert.rejects(run(db, uid, lease, { pageSize }));
  await jobRef(uid).update({ checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT });
  await assert.rejects(run(db, uid, lease), /checkpoint/);
  await jobRef(uid).update({ checkpoint: null }); await run(db, uid, lease);
  for (const collection of ['accountDeletionJobs', 'accountDeletionBarriers', 'accountDeletionOutbox']) await db.doc(`${collection}/${uid}`).update({ deletionRequestedAt: Timestamp.fromMillis(1) });
  await assert.rejects(run(db, uid, lease), /Invalid/);
  const recovery = 'ratings-recovery'; await seed(recovery); await finish(recovery);
  await jobRef(recovery).update({ phase: 'ratings', checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT });
  await run(db, recovery, lease); assert.equal((await jobRef(recovery).get()).data().phase, 'verify');
});
test('lost commit acknowledgement resumes without double decrement', async () => {
  const uid = 'lost-rating-ack', target = 'lost-rating-target';
  const a = await live('lost-ack-a', uid, target, 5), b = await live('lost-ack-b', uid, target, 3);
  await seed(uid); let lose = true;
  const flaky = new Proxy(db, { get(object, key) {
    if (key === 'runTransaction') return async (...args) => {
      const result = await object.runTransaction(...args);
      if (lose) { lose = false; throw Object.assign(new Error('private'), { code: 14 }); }
      return result;
    };
    const value = Reflect.get(object, key, object); return typeof value === 'function' ? value.bind(object) : value;
  } });
  await assert.rejects(run(flaky, uid, lease, { pageSize: 1 }), /cleanup failed/);
  assert.deepEqual(await totals(target), [1, 3, 3]);
  assert.equal((await a.get()).exists, false); assert.equal((await b.get()).exists, true);
  await jobRef(uid).update({ nextAttemptAt: new Date(0) });
  const fresh = { ...lease, leaseToken: 'retry' }; await acquireDeletionLease(db, uid, fresh); await finish(uid, fresh);
  assert.deepEqual(await totals(target), [0, 0, 0]);
});
test('required targeted collection-group indexes exist once', () => {
  const indexes = JSON.parse(readFileSync(new URL('../firestore.indexes.json', import.meta.url)));
  for (const fieldPath of ['raterUid', 'ratedUid', 'matchId']) {
    const entries = indexes.fieldOverrides.filter((entry) => entry.collectionGroup === 'ratings' && entry.fieldPath === fieldPath);
    assert.equal(entries.length, 1);
    assert.ok(entries[0].indexes.some((index) => index.queryScope === 'COLLECTION_GROUP' && index.order === 'ASCENDING'));
  }
});
test('rating whose create trigger has not contributed deletes without decrement and normalizes zero', async () => {
  const uid = 'not-yet-contributed', target = 'not-yet-target'; await seed(uid);
  await profile(target).set({ uid: target });
  const ref = rating('not-yet-match', uid, target);
  await ref.set({ matchId: 'not-yet-match', raterUid: uid, ratedUid: target, rating: 5 });
  await finish(uid);
  assert.deepEqual(await totals(target), [0, 0, 0]);
  assert.equal((await contribution(ref).get()).exists, false);
  await reconcileRating(db, ref.path);
  assert.deepEqual(await totals(target), [0, 0, 0]);
});
