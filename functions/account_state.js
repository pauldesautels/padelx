import { assertSafeFirestore } from './backend_environment.js';
import { HttpsError } from 'firebase-functions/v2/https';

export const ACCOUNT_SCHEMA_VERSION = 1;
export const DELETION_BARRIERS = 'accountDeletionBarriers';
export const DELETION_JOBS = 'accountDeletionJobs';
export const DELETION_PHASES = Object.freeze([
  'accepted', 'disableAuth', 'matches', 'joinRequests', 'notifications',
  'ratings', 'verify', 'deleteAuth', 'complete',
]);

// Pure schema builder only: this slice never accepts or starts deletion jobs.
export function deletionStateFor(uid, deletionRequestedAt) {
  if (typeof uid !== 'string' || !uid || uid.includes('/')
      || !(deletionRequestedAt instanceof Date) || !Number.isFinite(deletionRequestedAt.getTime())) {
    throw new Error('Valid UID and server cutoff required.');
  }
  const common = { uid, schemaVersion: ACCOUNT_SCHEMA_VERSION, deletionRequestedAt };
  return {
    barrier: { ...common, status: 'deleting' },
    job: { ...common, status: 'pending', phase: 'accepted', checkpoint: null,
      attemptCount: 0, nextAttemptAt: deletionRequestedAt, leaseExpiresAt: null,
      lastErrorCode: null, completedAt: null },
  };
}

export function requireSignedIn(request) {
  const uid = request?.auth?.uid;
  if (typeof uid !== 'string' || !uid || uid.includes('/')) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  return uid;
}

export function requireRecentAuthentication(request, { nowSeconds = Date.now() / 1000, maxAgeSeconds = 300 } = {}) {
  const uid = requireSignedIn(request);
  const authenticatedAt = request.auth.token?.auth_time;
  if (!Number.isFinite(nowSeconds) || !Number.isFinite(maxAgeSeconds) || maxAgeSeconds <= 0
      || !Number.isSafeInteger(authenticatedAt) || authenticatedAt <= 0
      || authenticatedAt > nowSeconds || nowSeconds - authenticatedAt > maxAgeSeconds) {
    throw new HttpsError('failed-precondition', 'Recent authentication required.');
  }
  return uid;
}

// Caller provides the already environment-validated Firestore instance.
// For destructive callables also check revocation/disabled state with Admin Auth.
export async function requireActiveAccount(firestore, request, { verified = true } = {}) {
  assertSafeFirestore(firestore);
  const uid = requireSignedIn(request);
  if (verified && request.auth.token?.email_verified !== true) {
    throw new HttpsError('permission-denied', 'Verified email required.');
  }
  if ((await firestore.collection(DELETION_BARRIERS).doc(uid).get()).exists) {
    throw new HttpsError('permission-denied', 'Account deletion is in progress.');
  }
  return uid;
}
