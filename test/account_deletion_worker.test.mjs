import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { deletionStateFor } from '../functions/account_state.js';
import { acquireDeletionLease, checkpointDeletion, retryDeletionLease, runDeletionStep, sanitizedWorkerErrorCategory, transitionDeletionPhase, DELETION_WORKER_PHASES, DELETION_PHASE_COMPLETE_CHECKPOINT } from '../functions/account_deletion_worker.js';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
const projectId = 'demo-padelx-worker';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'worker-tests');
const db = getFirestore(app);
after(() => deleteApp(app));
const a = { leaseOwner: 'worker-a', leaseToken: 'token-a' };
const b = { leaseOwner: 'worker-b', leaseToken: 'token-b' };
const cutoff = new Date('2026-01-01');
const read = async (uid) => (await db.doc(`accountDeletionJobs/${uid}`).get()).data();
async function seed(uid) {
  await db.doc(`accountDeletionJobs/${uid}`).set(deletionStateFor(uid, cutoff).job);
  await db.doc(`accountDeletionOutbox/${uid}`).set({ status: 'ready_for_cleanup' });
}
const progress = (expectedCheckpoint, checkpoint) => ({ phase: 'accepted', expectedCheckpoint, checkpoint });

test('worker errors retain only stable non-sensitive categories', () => {
  assert.equal(sanitizedWorkerErrorCategory({ code: 9, message: 'query requires an index at a private URL' }), 'missing-index');
  assert.equal(sanitizedWorkerErrorCategory({ code: 'permission-denied', message: 'private/path' }), 'permission-denied');
  assert.equal(sanitizedWorkerErrorCategory(new Error('private/path and identity')), 'invalid-worker-state');
});

test('transactional acquisition excludes competitors, replays once, and fences expired tokens', async () => {
  const uid = 'leasing'; await seed(uid);
  const now = new Date();
  assert.equal(await acquireDeletionLease(db, uid, a, { now, leaseMs: 1000 }), true);
  const first = await read(uid);
  assert.equal(await acquireDeletionLease(db, uid, a, { now }), true);
  assert.equal(await acquireDeletionLease(db, uid, b, { now }), false);
  assert.equal((await read(uid)).attemptCount, 1);
  assert.equal((await read(uid)).leaseExpiresAt.toMillis(), first.leaseExpiresAt.toMillis());
  const expired = new Date(now.getTime() + 1000);
  await assert.rejects(checkpointDeletion(db, uid, a, progress(null, 0), expired), /lease lost/);
  assert.equal(await acquireDeletionLease(db, uid, a, { now: expired }), false);
  assert.equal(await acquireDeletionLease(db, uid, b, { now: expired }), true);
  await assert.rejects(checkpointDeletion(db, uid, a, progress(null, 0), expired), /lease lost/);
  await assert.rejects(retryDeletionLease(db, uid, a, { now: expired }), /lease lost/);
  assert.equal((await read(uid)).attemptCount, 2);
  assert.equal((await read(uid)).deletionRequestedAt.toMillis(), cutoff.getTime());
});

test('concurrent first acquisitions have exactly one winner', async () => {
  await seed('race');
  const results = await Promise.all([a, b].map((lease) => acquireDeletionLease(db, 'race', lease)));
  assert.equal(results.filter(Boolean).length, 1);
  assert.equal((await read('race')).attemptCount, 1);
});

test('checkpoint replay and retry preserve successful progress; failed work never advances', async () => {
  const uid = 'progress'; await seed(uid);
  await acquireDeletionLease(db, uid, a);
  for (const wrong of [b, { ...a, leaseToken: 'wrong' }, { ...a, leaseOwner: 'wrong' }]) {
    await assert.rejects(checkpointDeletion(db, uid, wrong, progress(null, 0)), /lease lost/);
  }
  await runDeletionStep(db, uid, a, progress(null, 0), async () => {});
  await checkpointDeletion(db, uid, a, progress(null, 0));
  await assert.rejects(checkpointDeletion(db, uid, a, progress(null, 1)), /checkpoint changed/);
  await assert.rejects(runDeletionStep(db, uid, a, progress(0, 1), async () => {
    throw new Error('private payload / secret');
  }), /private payload/);
  const failed = await read(uid);
  assert.equal(failed.checkpoint, 0);
  assert.equal(failed.attemptCount, 1);
  assert.equal(failed.lastErrorCode, 'worker-work-failed');
  assert.equal(failed.leaseOwner, null);
  assert.equal(failed.leaseExpiresAt, null);
  await retryDeletionLease(db, uid, a);
  assert.equal((await read(uid)).nextAttemptAt.toMillis(), failed.nextAttemptAt.toMillis());
  assert.equal(await acquireDeletionLease(db, uid, b, { now: new Date(failed.nextAttemptAt.toMillis() - 1) }), false);
  const due = new Date(failed.nextAttemptAt.toMillis());
  assert.equal(await acquireDeletionLease(db, uid, b, { now: due }), true);
  await checkpointDeletion(db, uid, b, progress(0, 1), due);
  await assert.rejects(checkpointDeletion(db, uid, b, { ...progress(1, 2), phase: 'complete' }, due));
  const done = await read(uid);
  assert.equal(done.checkpoint, 1);
  assert.equal(done.attemptCount, 2);
  assert.equal(done.lastErrorCode, null);
  assert.equal(done.deletionRequestedAt.toMillis(), cutoff.getTime());
  assert.equal(done.completedAt, null);
  assert.equal(done.phase, 'accepted');
  assert.equal(done.status, 'pending');
});

test('worker rejects unready jobs and unsafe environments before database access', async () => {
  await seed('unready');
  await db.doc('accountDeletionOutbox/unready').update({ status: 'auth_pending' });
  assert.equal(await acquireDeletionLease(db, 'unready', a), false);
  const fake = { projectId: 'padelx-f168f', collection: () => assert.fail('must not access production') };
  for (const action of [() => acquireDeletionLease(fake, 'x', a),
    () => checkpointDeletion(fake, 'x', a, progress(null, 0)),
    () => transitionDeletionPhase(fake, 'x', a, { expectedPhase: 'accepted', nextPhase: 'matches' }),
    () => retryDeletionLease(fake, 'x', a),
    () => runDeletionStep(fake, 'x', a, progress(null, 0), async () => assert.fail())]) {
    await assert.rejects(action, /trusted runtime/);
  }
});

const firstTransition = { expectedPhase: 'accepted', nextPhase: 'matches' };
async function readyForTransition(uid, now = new Date()) {
  await seed(uid);
  await acquireDeletionLease(db, uid, a, { now });
  await checkpointDeletion(db, uid, a, progress(null, DELETION_PHASE_COMPLETE_CHECKPOINT), now);
}

test('ordered transitions reset checkpoint, preserve lease/cutoff, and replay without erasing next-phase progress', async () => {
  const uid = 'transitions'; await readyForTransition(uid);
  const original = await read(uid);
  await Promise.all([1, 2].map(() => transitionDeletionPhase(db, uid, a, firstTransition)));
  let job = await read(uid);
  assert.equal(job.phase, 'matches');
  assert.equal(job.checkpoint, null);
  assert.equal(job.leaseOwner, original.leaseOwner);
  assert.equal(job.leaseToken, original.leaseToken);
  assert.equal(job.leaseExpiresAt.toMillis(), original.leaseExpiresAt.toMillis());
  await checkpointDeletion(db, uid, a, { phase: 'matches', expectedCheckpoint: null, checkpoint: 0 });
  await transitionDeletionPhase(db, uid, a, firstTransition);
  assert.equal((await read(uid)).checkpoint, 0);
  for (let i = 1; i < DELETION_WORKER_PHASES.length - 1; i++) {
    const phase = DELETION_WORKER_PHASES[i];
    await checkpointDeletion(db, uid, a, { phase, expectedCheckpoint: i === 1 ? 0 : null,
      checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT });
    await transitionDeletionPhase(db, uid, a, { expectedPhase: phase, nextPhase: DELETION_WORKER_PHASES[i + 1] });
    assert.equal((await read(uid)).checkpoint, null);
  }
  job = await read(uid);
  assert.equal(job.phase, 'deleteAuth');
  assert.equal(job.status, 'pending');
  assert.equal(job.completedAt, null);
  assert.equal(job.deletionRequestedAt.toMillis(), cutoff.getTime());
  assert.equal(job.attemptCount, original.attemptCount);
  await assert.rejects(transitionDeletionPhase(db, uid, a, { expectedPhase: 'deleteAuth', nextPhase: 'complete' }), /Invalid/);
});

test('transition rejects skipping, backward, arbitrary, wrong-current and incomplete phases without writes', async () => {
  const uid = 'invalid-transitions'; await seed(uid); await acquireDeletionLease(db, uid, a);
  for (const checkpoint of [null, 0, 5]) {
    await db.doc(`accountDeletionJobs/${uid}`).update({ checkpoint });
    await assert.rejects(transitionDeletionPhase(db, uid, a, firstTransition), /incomplete/);
  }
  const before = await read(uid);
  for (const input of [
    { expectedPhase: 'accepted', nextPhase: 'ratings' },
    { expectedPhase: 'matches', nextPhase: 'accepted' },
    { expectedPhase: 'accepted', nextPhase: 'arbitrary' },
    { expectedPhase: 'arbitrary', nextPhase: 'matches' },
    { expectedPhase: 'disableAuth', nextPhase: 'matches' },
  ]) await assert.rejects(transitionDeletionPhase(db, uid, a, input), /Invalid/);
  await assert.rejects(transitionDeletionPhase(db, uid, a, { expectedPhase: 'matches', nextPhase: 'joinRequests' }), /phase changed/);
  assert.deepEqual(await read(uid), before);
});

test('transition fences wrong owner/token, expiry, reclamation and stale replays', async () => {
  const uid = 'transition-fencing'; const now = new Date(); await readyForTransition(uid, now);
  for (const lease of [{ ...a, leaseOwner: 'wrong' }, { ...a, leaseToken: 'wrong' }]) {
    await assert.rejects(transitionDeletionPhase(db, uid, lease, firstTransition, now), /lease lost/);
  }
  const expiry = new Date((await read(uid)).leaseExpiresAt.toMillis());
  await assert.rejects(transitionDeletionPhase(db, uid, a, firstTransition, expiry), /lease lost/);
  assert.equal(await acquireDeletionLease(db, uid, b, { now: expiry }), true);
  await assert.rejects(transitionDeletionPhase(db, uid, a, firstTransition, expiry), /lease lost/);
  await transitionDeletionPhase(db, uid, b, firstTransition, expiry);
  await assert.rejects(transitionDeletionPhase(db, uid, a, firstTransition, expiry), /lease lost/);
  const nextExpiry = new Date((await read(uid)).leaseExpiresAt.toMillis());
  await assert.rejects(transitionDeletionPhase(db, uid, b, firstTransition, nextExpiry), /lease lost/);
  assert.equal(await acquireDeletionLease(db, uid, { ...a, leaseToken: 'fresh' }, { now: nextExpiry }), true);
  await assert.rejects(transitionDeletionPhase(db, uid, { ...a, leaseToken: 'fresh' }, firstTransition, nextExpiry), /phase changed/);
  assert.equal((await read(uid)).phase, 'matches');
});

test('terminal and blocked jobs cannot transition, including replay', async () => {
  const uid = 'blocked-transitions'; await readyForTransition(uid);
  for (const patch of [{ status: 'blocked' }, { status: 'complete' },
    { status: 'pending', completedAt: new Date() },
    { status: 'pending', completedAt: null, phase: 'complete' }]) {
    await db.doc(`accountDeletionJobs/${uid}`).update(patch);
    const before = await read(uid);
    await assert.rejects(transitionDeletionPhase(db, uid, a, firstTransition), /cannot transition/);
    assert.deepEqual(await read(uid), before);
  }
  await db.doc(`accountDeletionJobs/${uid}`).update({ phase: 'accepted' });
  await transitionDeletionPhase(db, uid, a, firstTransition);
  await db.doc(`accountDeletionJobs/${uid}`).update({ status: 'blocked' });
  await assert.rejects(transitionDeletionPhase(db, uid, a, firstTransition), /cannot transition/);
});

const { runAcceptedDeletionPhase } = await import('../functions/account_deletion_worker.js');
async function accepted(uid, patch = {}) {
  const state = deletionStateFor(uid, cutoff);
  await db.doc(`accountDeletionBarriers/${uid}`).set(state.barrier);
  await db.doc(`accountDeletionJobs/${uid}`).set({ ...state.job,
    authDisabledAt: cutoff, authRevokedAt: cutoff, authMissing: false, ...patch });
  await db.doc(`accountDeletionOutbox/${uid}`).set({ ...state.barrier,
    jobId: uid, status: 'ready_for_cleanup' });
  assert.equal(await acquireDeletionLease(db, uid, a), true);
}
function authSpy(fail) {
  const calls = [];
  return { calls, updateUser: async (uid, data) => {
    assert.deepEqual(data, { disabled: true }); calls.push('disable'); await fail?.('disable');
  }, revokeRefreshTokens: async () => { calls.push('revoke'); await fail?.('revoke'); } };
}
test('accepted validates fixed cutoff, transitions and replays without duplicating completed Auth', async () => {
  const uid = 'accepted-valid'; await accepted(uid); const auth = authSpy();
  await Promise.all([1, 2].map(() => runAcceptedDeletionPhase(db, auth, uid, a)));
  assert.equal((await read(uid)).phase, 'matches');
  assert.equal((await read(uid)).checkpoint, null);
  await checkpointDeletion(db, uid, a, { phase: 'matches', expectedCheckpoint: null, checkpoint: 0 });
  await runAcceptedDeletionPhase(db, auth, uid, a);
  const job = await read(uid);
  assert.equal(job.checkpoint, 0);
  assert.equal(job.deletionRequestedAt.toMillis(), cutoff.getTime());
  assert.equal(job.attemptCount, 1);
  assert.deepEqual(auth.calls, []);
});
test('accepted rejects malformed lifecycle records and unexpected profiles without effects', async () => {
  const cases = [
    ['accountDeletionBarriers', null], ['accountDeletionOutbox', null],
    ['accountDeletionBarriers', { status: 'complete' }],
    ['accountDeletionBarriers', { deletionRequestedAt: new Date(1) }],
    ['accountDeletionOutbox', { jobId: 'other' }],
    ['accountDeletionOutbox', { status: 'auth_pending' }],
    ...['accountDeletionJobs', 'accountDeletionBarriers', 'accountDeletionOutbox'].flatMap((c) =>
      [[c, { uid: 'other' }], [c, { schemaVersion: 2 }], [c, { deletionRequestedAt: 'bad' }]]),
    ['users', { name: 'unexpected' }], ['publicProfiles', { name: 'unexpected' }],
    ['accountDeletionJobs', { authDisabledAt: null }],
    ['accountDeletionJobs', { authRevokedAt: 'bad' }],
    ['accountDeletionJobs', { authMissing: 'false' }],
    ['accountDeletionJobs', { checkpoint: 1 }],
  ];
  for (const [i, [collection, patch]] of cases.entries()) {
    const uid = `accepted-invalid-${i}`; await accepted(uid);
    const ref = db.doc(`${collection}/${uid}`);
    if (patch === null) await ref.delete(); else await ref.set(patch, { merge: true });
    const before = await read(uid); const auth = authSpy();
    await assert.rejects(runAcceptedDeletionPhase(db, auth, uid, a), /Invalid accepted/);
    assert.deepEqual(await read(uid), before); assert.deepEqual(auth.calls, []);
  }
});
test('accepted resumes partial Auth failure and treats missing Auth as safe success', async () => {
  const uid = 'accepted-retry'; await accepted(uid, { authDisabledAt: null, authRevokedAt: null });
  const auth = authSpy((op) => { if (op === 'revoke') throw new Error('secret'); });
  await assert.rejects(runAcceptedDeletionPhase(db, auth, uid, a), /^Error: Auth lockdown failed/);
  let job = await read(uid);
  assert.equal(job.phase, 'accepted'); assert.equal(job.checkpoint, null);
  assert.ok(job.authDisabledAt); assert.equal(job.authRevokedAt, null);
  assert.equal(job.lastErrorCode, 'worker-work-failed');
  await acquireDeletionLease(db, uid, b, { now: new Date(job.nextAttemptAt.toMillis()) });
  const missing = authSpy(() => { throw Object.assign(new Error('missing'), { code: 'auth/user-not-found' }); });
  await runAcceptedDeletionPhase(db, missing, uid, b);
  assert.deepEqual(missing.calls, ['revoke']);
  job = await read(uid); assert.equal(job.phase, 'matches'); assert.equal(job.authMissing, true);
  assert.equal(job.deletionRequestedAt.toMillis(), cutoff.getTime());
  await accepted('accepted-missing', { authDisabledAt: null, authRevokedAt: null });
  missing.calls.length = 0;
  await runAcceptedDeletionPhase(db, missing, 'accepted-missing', a);
  assert.deepEqual(missing.calls, ['disable', 'revoke']);
  assert.equal((await read('accepted-missing')).authMissing, true);
});
test('accepted fences wrong and expired leases, including lease loss during Auth work', async () => {
  const uid = 'accepted-fence'; await accepted(uid, { authDisabledAt: null, authRevokedAt: null });
  const auth = authSpy();
  await assert.rejects(runAcceptedDeletionPhase(db, auth, uid, b), /lease lost/);
  assert.deepEqual(auth.calls, []);
  const expire = authSpy(async () => {
    await db.doc(`accountDeletionJobs/${uid}`).update({ leaseExpiresAt: new Date(0) });
    await acquireDeletionLease(db, uid, b);
  });
  await assert.rejects(runAcceptedDeletionPhase(db, expire, uid, a), /lease lost/);
  const job = await read(uid);
  assert.equal(job.phase, 'accepted'); assert.equal(job.authDisabledAt, null);
  await assert.rejects(runAcceptedDeletionPhase(db, auth, uid, a), /lease lost/);
});
test('accepted revalidates cutoff and profile absence after external Auth work', async () => {
  for (const type of ['profile', 'cutoff']) {
    const uid = `accepted-race-${type}`;
    await accepted(uid, { authRevokedAt: null });
    const auth = authSpy(async () => {
      if (type === 'profile') await db.doc(`users/${uid}`).set({ unexpected: true });
      else for (const c of ['accountDeletionJobs', 'accountDeletionBarriers', 'accountDeletionOutbox']) {
        await db.doc(`${c}/${uid}`).update({ deletionRequestedAt: new Date(cutoff.getTime() - 1) });
      }
    });
    await assert.rejects(runAcceptedDeletionPhase(db, auth, uid, a), /Invalid accepted/);
    assert.equal((await read(uid)).phase, 'accepted');
    assert.equal((await read(uid)).checkpoint, null);
  }
});
test('accepted resumes reserved completion checkpoint after a lost transition attempt', async () => {
  const uid = 'accepted-marker';
  await accepted(uid, { checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT });
  const auth = authSpy();
  await runAcceptedDeletionPhase(db, auth, uid, a);
  assert.equal((await read(uid)).phase, 'matches');
  assert.equal((await read(uid)).checkpoint, null);
  assert.deepEqual(auth.calls, []);
});
test('accepted schedules sanitized retry after transient database failure', async () => {
  const uid = 'accepted-database-retry'; await accepted(uid);
  let fail = true;
  const flaky = new Proxy(db, { get(target, key) {
    if (key === 'runTransaction') return (...args) => {
      if (fail) { fail = false; return Promise.reject(Object.assign(new Error('private detail'), { code: 14 })); }
      return target.runTransaction(...args);
    };
    const value = Reflect.get(target, key, target);
    return typeof value === 'function' ? value.bind(target) : value;
  } });
  await assert.rejects(runAcceptedDeletionPhase(flaky, authSpy(), uid, a), /Accepted preparation failed/);
  const job = await read(uid);
  assert.equal(job.phase, 'accepted'); assert.equal(job.status, 'retry_wait');
  assert.equal(job.lastErrorCode, 'worker-work-failed');
  assert.ok(job.authDisabledAt); assert.ok(job.authRevokedAt);
});
