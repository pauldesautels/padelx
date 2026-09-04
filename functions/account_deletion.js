import { HttpsError } from 'firebase-functions/v2/https';
import { assertSafeFirestore } from './backend_environment.js';
import { deletionStateFor, requireRecentAuthentication, DELETION_BARRIERS, DELETION_JOBS } from './account_state.js';

export const DELETION_OUTBOX = 'accountDeletionOutbox';

function admissionEnvironment(db) {
  const environment = assertSafeFirestore(db);
  // Admission must not become available on staging before the cleanup rollout.
  if (environment.mode !== 'emulator' && process.env.PADELX_ACCOUNT_DELETION_ENABLED !== 'true') {
    throw new HttpsError('failed-precondition', 'Account deletion is not enabled.');
  }
}

export function deletionRequestUid(request, now = new Date()) {
  const uid = requireRecentAuthentication(request, { nowSeconds: now.getTime() / 1000 });
  if (request.data != null && (typeof request.data !== 'object' || Array.isArray(request.data)
      || Object.keys(request.data).length !== 0)) {
    throw new HttpsError('invalid-argument', 'No payload fields are accepted.');
  }
  return uid;
}

// Transaction boundary is intentionally separate from Auth/network effects.
export async function acceptAccountDeletion(db, request, now = new Date()) {
  admissionEnvironment(db);
  const uid = deletionRequestUid(request, now);
  const jobRef = db.collection(DELETION_JOBS).doc(uid);
  return db.runTransaction(async (tx) => {
    const barrierRef = db.collection(DELETION_BARRIERS).doc(uid);
    const outboxRef = db.collection(DELETION_OUTBOX).doc(uid);
    const [job, barrier, outbox] = await tx.getAll(jobRef, barrierRef, outboxRef);
    if (job.exists || barrier.exists || outbox.exists) {
      // Never invent a new cutoff over partially corrupted lifecycle records.
      if (!job.exists || !barrier.exists || !outbox.exists
          || job.data().uid !== uid || barrier.data().uid !== uid || outbox.data().uid !== uid
          || !Number.isFinite(job.data().deletionRequestedAt?.toMillis?.())
          || barrier.data().deletionRequestedAt?.toMillis?.() !== job.data().deletionRequestedAt.toMillis()
          || outbox.data().deletionRequestedAt?.toMillis?.() !== job.data().deletionRequestedAt.toMillis()) {
        throw new HttpsError('internal', 'Deletion state requires recovery.');
      }
    } else {
      const state = deletionStateFor(uid, now);
      tx.create(barrierRef, state.barrier);
      tx.create(jobRef, { ...state.job, phase: 'disableAuth',
        authDisabledAt: null, authRevokedAt: null, authMissing: false });
      tx.create(outboxRef, { uid, schemaVersion: 1, jobId: uid,
        deletionRequestedAt: now, status: 'auth_pending', attemptCount: 0,
        nextAttemptAt: now, leaseExpiresAt: null, lastErrorCode: null });
    }
    // Reassert absence on retries; never recreate a private/public profile.
    tx.delete(db.collection('users').doc(uid));
    tx.delete(db.collection('publicProfiles').doc(uid));
    return { status: 'accepted' };
  });
}

// Shared idempotent Auth operation; callers own their durable progress writes.
export async function performDeletionAuthLock(auth, uid, operation) {
  if (!['disable', 'revoke'].includes(operation)) throw new Error('Invalid Auth lockdown operation.');
  try {
    if (operation === 'disable') await auth.updateUser(uid, { disabled: true });
    else await auth.revokeRefreshTokens(uid);
    return false;
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    return true;
  }
}

export async function lockDeletionAuth(db, auth, uid, now = new Date()) {
  admissionEnvironment(db);
  const jobRef = db.collection(DELETION_JOBS).doc(uid);
  const outboxRef = db.collection(DELETION_OUTBOX).doc(uid);
  const [job, barrier, outbox] = await db.getAll(jobRef,
    db.collection(DELETION_BARRIERS).doc(uid), outboxRef);
  if (!job.exists || !barrier.exists || !outbox.exists) throw new Error('Missing durable deletion acceptance.');
  if (job.data().status === 'blocked') return;
  if (job.data().phase !== 'disableAuth') {
    await db.runTransaction(async tx => {
      const current = (await tx.get(jobRef)).data();
      if (current?.status !== 'blocked' && current?.phase === 'accepted' && current.authDisabledAt && current.authRevokedAt) {
        tx.update(outboxRef, { status: 'ready_for_cleanup', nextAttemptAt: now });
      }
    });
    return;
  }
  try {
    let missing = job.data().authMissing === true;
    if (!job.data().authDisabledAt) {
      missing = (await performDeletionAuthLock(auth, uid, 'disable')) || missing;
      await db.runTransaction(async tx => {
        const current = (await tx.get(jobRef)).data();
        if (current?.phase === 'disableAuth' && current.status !== 'blocked') tx.update(jobRef, { authDisabledAt: now, authMissing: missing });
      });
    }
    if (!job.data().authRevokedAt) {
      // Even when the previous attempt observed a missing user, call Auth again:
      // its current state is authoritative. Missing remains a safe success.
      missing = (await performDeletionAuthLock(auth, uid, 'revoke')) || missing;
      await db.runTransaction(async tx => {
        const current = (await tx.get(jobRef)).data();
        if (current?.phase === 'disableAuth' && current.status !== 'blocked') tx.update(jobRef, { authRevokedAt: now, authMissing: missing });
      });
    }
    await db.runTransaction(async (tx) => {
      const current = await tx.get(jobRef);
      if (current.data()?.phase !== 'disableAuth' || current.data()?.status === 'blocked') return;
      if (!current.data()?.authDisabledAt || !current.data()?.authRevokedAt) throw new Error('Auth lockdown incomplete.');
      tx.update(jobRef, { status: 'pending', phase: 'accepted', nextAttemptAt: now, lastErrorCode: null, attemptCount: 0 });
      tx.update(outboxRef, { status: 'ready_for_cleanup', nextAttemptAt: now, lastErrorCode: null, attemptCount: 0 });
    });
  } catch (error) {
    await db.runTransaction(async (tx) => {
      const current = await tx.get(jobRef);
      // A concurrent successful invocation must never be regressed by failure.
      if (current.data()?.phase !== 'disableAuth' || current.data()?.status === 'blocked') return;
      const attempts = Math.min(8, (current.data()?.attemptCount ?? 0) + 1);
      const nextAttemptAt = new Date(now.getTime() + Math.min(3600000, 1000 * 2 ** attempts));
      const retry = { attemptCount: attempts, nextAttemptAt, lastErrorCode: 'auth-lockdown-failed' };
      tx.update(jobRef, { ...retry, status: 'retry_wait' });
      tx.update(outboxRef, { ...retry, status: 'auth_pending' });
    });
    throw error;
  }
}

export async function admitAccountDeletion(db, auth, request, now = new Date()) {
  const receipt = await acceptAccountDeletion(db, request, now);
  try { await lockDeletionAuth(db, auth, request.auth.uid, now); }
  catch { /* Durable outbox creation trigger retries lockdown independently. */ }
  return receipt;
}

// Testable dispatch adapter retained for diagnostics/alternative transports.
// Scheduled recovery uses account_deletion_dispatch.js. Never consume the outbox
// on enqueue: only fenced finalization acknowledges completed deletion.
export async function dispatchDeletionOutbox(db, adapter, now = new Date()) {
  admissionEnvironment(db);
  const due = await db.collection(DELETION_OUTBOX).where('nextAttemptAt', '<=', now)
    .orderBy('nextAttemptAt').limit(20).get();
  return Promise.allSettled(due.docs.map((doc) => adapter({ jobId: doc.id, status: doc.data().status })));
}
