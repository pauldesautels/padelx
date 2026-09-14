import { assertSafeFirestore } from './backend_environment.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { readEffectiveAccountEnforcement } from './account_enforcement.js';

export const LEGACY_ACCOUNT_SCHEMA_VERSION = 1;
// Retained for Phase 8 fixtures/operators. New admissions use CURRENT_*.
export const ACCOUNT_SCHEMA_VERSION = LEGACY_ACCOUNT_SCHEMA_VERSION;
export const CURRENT_DELETION_SCHEMA_VERSION = 2;
export const DELETION_BARRIERS = 'accountDeletionBarriers';
export const DELETION_JOBS = 'accountDeletionJobs';
export const DELETION_PHASES = Object.freeze([
  'accepted', 'disableAuth', 'matches', 'joinRequests', 'notifications',
  'social', 'messaging', 'ratings', 'storage', 'verify', 'deleteAuth', 'complete',
]);
export const DELETION_PHASES_BY_VERSION = Object.freeze({
  1: Object.freeze(['accepted', 'matches', 'joinRequests', 'notifications', 'ratings', 'verify', 'deleteAuth']),
  2: Object.freeze(['accepted', 'matches', 'joinRequests', 'social', 'messaging',
    'notifications', 'ratings', 'storage', 'verify', 'deleteAuth']),
});

export function deletionPhasesFor(schemaVersion) {
  const phases = DELETION_PHASES_BY_VERSION[schemaVersion];
  if (!phases) throw new Error('Unsupported deletion schema version.');
  return phases;
}

// Pure schema builder only: this slice never accepts or starts deletion jobs.
export function deletionStateFor(uid, deletionRequestedAt, schemaVersion = ACCOUNT_SCHEMA_VERSION) {
  if (typeof uid !== 'string' || !uid || uid.includes('/')
      || !(deletionRequestedAt instanceof Date) || !Number.isFinite(deletionRequestedAt.getTime())) {
    throw new Error('Valid UID and server cutoff required.');
  }
  deletionPhasesFor(schemaVersion);
  const common = { uid, schemaVersion, deletionRequestedAt };
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
export async function requireActiveAccount(firestore, request, { verified = true, now = new Date() } = {}) {
  assertSafeFirestore(firestore);
  const uid = requireSignedIn(request);
  if (verified && request.auth.token?.email_verified !== true) {
    throw new HttpsError('permission-denied', 'Verified email required.');
  }
  if ((await firestore.collection(DELETION_BARRIERS).doc(uid).get()).exists) {
    throw new HttpsError('permission-denied', 'Account deletion is in progress.');
  }
  if (await readEffectiveAccountEnforcement(firestore, uid, now)) {
    throw new HttpsError('permission-denied', 'Account access is restricted.');
  }
  return uid;
}
