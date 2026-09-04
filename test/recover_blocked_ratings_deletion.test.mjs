import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import {
  recoverBlockedRatingsDeletion,
  recoveryOptions,
} from '../tool/recover_blocked_ratings_deletion.mjs';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-padelx-recovery';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'ratings-recovery-tests');
const db = getFirestore(app);
after(() => deleteApp(app));
const cutoff = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));

async function seed(uid, { job = {}, barrier = {}, outbox = {} } = {}) {
  await Promise.all([
    db.doc(`accountDeletionJobs/${uid}`).set({
      uid, schemaVersion: 1, deletionRequestedAt: cutoff,
      status: 'blocked', phase: 'ratings', checkpoint: null,
      attemptCount: 8, failureCount: 8,
      nextAttemptAt: null, lastErrorCode: 'retry-exhausted',
      completedAt: null, leaseOwner: null, leaseToken: 'expired-token',
      leaseExpiresAt: null, authDisabledAt: cutoff, authRevokedAt: cutoff,
      authMissing: false, ...job,
    }),
    db.doc(`accountDeletionBarriers/${uid}`).set({
      uid, schemaVersion: 1, deletionRequestedAt: cutoff,
      status: 'deleting', ...barrier,
    }),
    db.doc(`accountDeletionOutbox/${uid}`).set({
      uid, schemaVersion: 1, deletionRequestedAt: cutoff,
      jobId: uid, status: 'ready_for_cleanup', nextAttemptAt: null,
      ...outbox,
    }),
  ]);
}

test('CLI requires the literal staging project and one UID', () => {
  assert.deepEqual(
    recoveryOptions(['--project=padelx-staging', '--uid=test']),
    { projectId: 'padelx-staging', uid: 'test', apply: false },
  );
  for (const args of [
    [], ['--project=padelx-f168f', '--uid=test'],
    ['--project=unknown', '--uid=test'], ['--project=padelx-staging'],
    ['--project=padelx-staging', '--uid=a/b'],
  ]) assert.throws(() => recoveryOptions(args));
});

test('dry-run is read-only and apply resets only scheduler retry fields', async () => {
  const uid = 'recoverable';
  await seed(uid);
  const before = (await db.doc(`accountDeletionJobs/${uid}`).get()).data();
  assert.deepEqual(
    await recoverBlockedRatingsDeletion(db, uid),
    { outcome: 'eligible', applied: false },
  );
  assert.deepEqual((await db.doc(`accountDeletionJobs/${uid}`).get()).data(), before);

  const result = await recoverBlockedRatingsDeletion(
    db, uid, { apply: true, now: new Date('2026-02-01T00:00:00Z') },
  );
  assert.deepEqual(result, { outcome: 'recovered', applied: true });
  const afterJob = (await db.doc(`accountDeletionJobs/${uid}`).get()).data();
  assert.equal(afterJob.status, 'retry_wait');
  assert.equal(afterJob.failureCount, 0);
  assert.equal(afterJob.lastErrorCode, null);
  assert.equal(afterJob.nextAttemptAt.toDate().toISOString(), '2026-02-01T00:00:00.000Z');
  for (const field of ['attemptCount', 'phase', 'checkpoint', 'ratingsCheckpoint',
    'leaseToken', 'authDisabledAt', 'authRevokedAt', 'deletionRequestedAt']) {
    assert.deepEqual(afterJob[field], before[field]);
  }
  assert.equal(
    (await db.doc(`accountDeletionOutbox/${uid}`).get()).data().nextAttemptAt
      .toDate().toISOString(),
    '2026-02-01T00:00:00.000Z',
  );
  assert.deepEqual(
    await recoverBlockedRatingsDeletion(db, uid, { apply: true }),
    { outcome: 'already-recovered', applied: false },
  );
});

test('accepts absent checkpoint and stale lease history exactly like the worker', async () => {
  const uid = 'staging-shaped-stale-lease';
  await seed(uid);
  const job = (await db.doc(`accountDeletionJobs/${uid}`).get()).data();
  assert.equal(Object.hasOwn(job, 'ratingsCheckpoint'), false);
  assert.equal(job.leaseOwner, null);
  assert.equal(job.leaseExpiresAt, null);
  assert.equal(typeof job.leaseToken, 'string');
  assert.deepEqual(
    await recoverBlockedRatingsDeletion(db, uid),
    { outcome: 'eligible', applied: false },
  );
});

test('accepts an expired owned lease but rejects unexpired or owner-without-expiry state', async () => {
  await seed('expired-owner', { job: {
    leaseOwner: 'old-worker',
    leaseExpiresAt: Timestamp.fromDate(new Date('2025-01-01')),
  } });
  assert.equal(
    (await recoverBlockedRatingsDeletion(db, 'expired-owner')).outcome,
    'eligible',
  );

  await seed('owner-no-expiry', { job: { leaseOwner: 'old-worker' } });
  await assert.rejects(recoverBlockedRatingsDeletion(db, 'owner-no-expiry'));
});

for (const [name, changes] of [
  ['wrong phase', { job: { phase: 'verify' } }],
  ['existing ratings checkpoint', { job: { ratingsCheckpoint: { givenDone: true } } }],
  ['wrong barrier', { barrier: { status: 'deleted' } }],
  ['wrong outbox', { outbox: { status: 'auth_pending' } }],
  ['missing Auth lockdown', { job: { authRevokedAt: null } }],
  ['active lease', { job: { leaseOwner: 'worker', leaseExpiresAt: Timestamp.fromDate(new Date('2099-01-01')) } }],
  ['wrong failure', { job: { lastErrorCode: 'ratings-ambiguous-state' } }],
  ['partial progress', { job: { checkpoint: 0 } }],
]) test(`fails closed for ${name}`, async () => {
  const uid = `guard-${name.replaceAll(' ', '-')}`;
  await seed(uid, changes);
  await assert.rejects(
    recoverBlockedRatingsDeletion(db, uid, { apply: true }),
  );
  assert.equal((await db.doc(`accountDeletionJobs/${uid}`).get()).data().status, 'blocked');
});
