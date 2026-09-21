import { pathToFileURL } from 'node:url';
import { initializeApp, applicationDefault, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { validateBackendEnvironment } from '../functions/backend_environment.js';

const STAGING_PROJECT = 'padelx-staging';

export function storageRecoveryOptions(args) {
  const allowed = args.every((arg) => arg === '--apply'
    || arg.startsWith('--project=') || arg.startsWith('--confirm-project=')
    || arg.startsWith('--uid='));
  const value = (name) => args.filter((arg) => arg.startsWith(`--${name}=`));
  const projects = value('project');
  const confirmations = value('confirm-project');
  const uids = value('uid');
  if (!allowed || projects.length !== 1 || confirmations.length !== 1 || uids.length !== 1
      || projects[0] !== `--project=${STAGING_PROJECT}`
      || confirmations[0] !== `--confirm-project=${STAGING_PROJECT}`) {
    throw new Error('Requires matching staging project confirmation and one UID.');
  }
  const uid = uids[0].slice('--uid='.length);
  if (!uid || uid.length > 128 || uid.includes('/')) throw new Error('Invalid UID.');
  return { projectId: STAGING_PROJECT, uid, apply: args.includes('--apply') };
}

function validTimestamp(value) {
  return Number.isFinite(value?.toMillis?.());
}

export async function recoverBlockedStorageDeletion(db, uid, {
  apply = false, now = new Date(),
} = {}) {
  const environment = validateBackendEnvironment({
    projectId: db.projectId,
    firestoreHost: process.env.FIRESTORE_EMULATOR_HOST,
    authHost: process.env.FIREBASE_AUTH_EMULATOR_HOST,
  });
  if (environment.mode !== 'emulator' && environment.projectId !== STAGING_PROJECT) {
    throw new Error('Recovery is restricted to staging.');
  }
  if (!uid || uid.length > 128 || uid.includes('/') || !Number.isFinite(now.getTime())) {
    throw new Error('Invalid recovery input.');
  }
  const jobRef = db.doc(`accountDeletionJobs/${uid}`);
  const barrierRef = db.doc(`accountDeletionBarriers/${uid}`);
  const outboxRef = db.doc(`accountDeletionOutbox/${uid}`);
  return db.runTransaction(async (tx) => {
    const [jobSnapshot, barrierSnapshot, outboxSnapshot] = await tx.getAll(
      jobRef, barrierRef, outboxRef,
    );
    const job = jobSnapshot.data();
    const barrier = barrierSnapshot.data();
    const outbox = outboxSnapshot.data();
    if (!job || !barrier || !outbox) throw new Error('Deletion lifecycle is incomplete.');
    const cutoff = job.deletionRequestedAt;
    const lifecycleMatches = [job, barrier, outbox].every((record) =>
      record.uid === uid && validTimestamp(record.deletionRequestedAt)
      && record.deletionRequestedAt.isEqual(cutoff));
    const leaseIsActive = validTimestamp(job.leaseExpiresAt)
      && job.leaseExpiresAt.toMillis() > now.getTime();
    const eligibleFailure = ['invalid-worker-state', 'storage-bucket-unavailable',
      'storage-configuration-invalid'].includes(job.lastFailureCategory);
    if (!lifecycleMatches || barrier.status !== 'deleting'
        || outbox.status !== 'ready_for_cleanup' || outbox.jobId !== uid
        || job.status !== 'blocked' || job.phase !== 'storage'
        || job.lastErrorCode !== 'retry-exhausted' || job.failureCount !== 8
        || !Number.isInteger(job.attemptCount) || job.attemptCount < 8
        || !eligibleFailure || leaseIsActive || job.completedAt !== null
        || !validTimestamp(job.authDisabledAt) || !validTimestamp(job.authRevokedAt)) {
      throw new Error('Deletion state is not eligible for storage recovery.');
    }
    if (!apply) return { outcome: 'eligible', applied: false };
    tx.update(jobRef, {
      status: 'retry_wait', failureCount: 0, nextAttemptAt: now,
      lastErrorCode: null, lastFailureCategory: null,
      leaseOwner: null, leaseExpiresAt: null,
    });
    tx.update(outboxRef, { nextAttemptAt: now });
    return { outcome: 'recovered', applied: true };
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const options = storageRecoveryOptions(process.argv.slice(2));
  const app = initializeApp({ credential: applicationDefault(), projectId: options.projectId });
  try {
    const result = await recoverBlockedStorageDeletion(
      getFirestore(app), options.uid, { apply: options.apply },
    );
    console.log(JSON.stringify({ project: 'staging', mode: options.apply ? 'apply' : 'dry-run',
      ...result }, null, 2));
  } finally {
    await deleteApp(app);
  }
}
