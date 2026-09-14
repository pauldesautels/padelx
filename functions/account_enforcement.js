import { createHash } from 'node:crypto';
import { HttpsError } from 'firebase-functions/v2/https';
import { assertSafeFirestore } from './backend_environment.js';

export const ACCOUNT_ENFORCEMENT = 'accountEnforcement';
export const MODERATION_ACTIONS = 'moderationActions';
export const ENFORCEMENT_SCHEMA_VERSION = 1;
export const MAX_SOURCE_REPORT_IDS = 20;
export const ENFORCEMENT_REASONS = Object.freeze([
  'harassment_abuse',
  'hate_discrimination',
  'sexual_misconduct',
  'threats_unsafe_behavior',
  'spam_scam',
  'impersonation',
  'privacy_violation',
  'fraud_deception',
  'malicious_reporting',
  'other_policy_violation',
]);

const validId = (value) => typeof value === 'string' && value.length >= 1
  && value.length <= 128 && !value.includes('/') && !/[\u0000-\u001f\u007f]/.test(value);
const validRequestId = (value) => typeof value === 'string'
  && /^[A-Za-z0-9_-]{16,128}$/.test(value);
const millis = (value) => value instanceof Date ? value.getTime() : value?.toMillis?.();

function operationError(message) {
  return new HttpsError('invalid-argument', message);
}

function validateCommon(input) {
  if (!input || typeof input !== 'object' || !validId(input.actorUid)
      || !validId(input.targetUid) || input.actorUid === input.targetUid
      || !validRequestId(input.requestId)) {
    throw operationError('Valid trusted enforcement context required.');
  }
}

function validateSources(sourceReportIds) {
  const values = sourceReportIds ?? [];
  if (!Array.isArray(values) || values.length > MAX_SOURCE_REPORT_IDS
      || values.some((id) => !validId(id)) || new Set(values).size !== values.length) {
    throw operationError('Invalid source reports.');
  }
  return values;
}

function actionId(kind, input) {
  return createHash('sha256')
    .update(`${kind}\0${input.actorUid}\0${input.targetUid}\0${input.requestId}`)
    .digest('hex');
}

export function getEffectiveAccountEnforcement(data, now = new Date()) {
  if (!data) return null;
  if (data.schemaVersion !== ENFORCEMENT_SCHEMA_VERSION || !validId(data.uid)
      || !ENFORCEMENT_REASONS.includes(data.reasonCode)) {
    return { status: 'banned', reasonCode: 'other_policy_violation', malformed: true };
  }
  if (data.status === 'banned') {
    return 'expiresAt' in data
      ? { status: 'banned', reasonCode: 'other_policy_violation', malformed: true }
      : { status: 'banned', reasonCode: data.reasonCode };
  }
  const expiry = millis(data.expiresAt);
  if (data.status !== 'suspended' || !Number.isFinite(expiry)) {
    return { status: 'banned', reasonCode: 'other_policy_violation', malformed: true };
  }
  return expiry > now.getTime()
    ? { status: 'suspended', reasonCode: data.reasonCode, expiresAt: data.expiresAt }
    : null;
}

export async function readEffectiveAccountEnforcement(firestore, uid, now = new Date()) {
  assertSafeFirestore(firestore);
  const snapshot = await firestore.collection(ACCOUNT_ENFORCEMENT).doc(uid).get();
  return getEffectiveAccountEnforcement(snapshot.data(), now);
}

export async function applyAccountEnforcement(firestore, auth, input, now = new Date()) {
  assertSafeFirestore(firestore);
  validateCommon(input);
  if (!['suspended', 'banned'].includes(input.status)
      || !ENFORCEMENT_REASONS.includes(input.reasonCode)) {
    throw operationError('Invalid enforcement policy.');
  }
  const sourceReportIds = validateSources(input.sourceReportIds);
  const expiry = millis(input.expiresAt);
  if (input.status === 'suspended' && (!Number.isFinite(expiry) || expiry <= now.getTime())) {
    throw operationError('Suspension requires a future expiry.');
  }
  if (input.status === 'banned' && input.expiresAt !== undefined) {
    throw operationError('A ban cannot expire.');
  }
  const enforcementRef = firestore.collection(ACCOUNT_ENFORCEMENT).doc(input.targetUid);
  const auditRef = firestore.collection(MODERATION_ACTIONS).doc(actionId('apply', input));
  const targetRef = firestore.collection('users').doc(input.targetUid);
  const reportRefs = sourceReportIds.map((id) => firestore.collection('reports').doc(id));
  const result = await firestore.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(targetRef, enforcementRef, auditRef, ...reportRefs);
    const [target, previous, audit, ...reports] = snapshots;
    if (!target.exists) throw new HttpsError('not-found', 'Account unavailable.');
    if (reports.some((report) => !report.exists)) throw operationError('Invalid source reports.');
    if (audit.exists) {
      const recorded = audit.data();
      if (recorded.targetUid !== input.targetUid || recorded.actorUid !== input.actorUid
          || recorded.newStatus !== input.status || recorded.reasonCode !== input.reasonCode
          || JSON.stringify(recorded.sourceReportIds) !== JSON.stringify(sourceReportIds)
          || millis(recorded.newExpiresAt) !== (input.status === 'suspended' ? expiry : undefined)) {
        throw new HttpsError('failed-precondition', 'Enforcement request conflict.');
      }
      return { applied: true, changed: false, idempotent: true };
    }
    const previousData = previous.data();
    const enforcement = {
      schemaVersion: ENFORCEMENT_SCHEMA_VERSION,
      uid: input.targetUid,
      status: input.status,
      reasonCode: input.reasonCode,
      createdAt: previousData?.createdAt ?? now,
      updatedAt: now,
      actionedBy: input.actorUid,
      sourceReportIds,
      ...(input.status === 'suspended' ? { expiresAt: input.expiresAt } : {}),
    };
    transaction.set(enforcementRef, enforcement);
    transaction.create(auditRef, {
      schemaVersion: ENFORCEMENT_SCHEMA_VERSION,
      type: input.status === 'suspended' ? 'suspension_applied' : 'ban_applied',
      targetUid: input.targetUid,
      actorUid: input.actorUid,
      reasonCode: input.reasonCode,
      sourceReportIds,
      createdAt: now,
      requestId: input.requestId,
      ...(previousData?.status ? { previousStatus: previousData.status } : {}),
      newStatus: input.status,
      ...(previousData?.expiresAt ? { previousExpiresAt: previousData.expiresAt } : {}),
      ...(input.status === 'suspended' ? { newExpiresAt: input.expiresAt } : {}),
    });
    return { applied: true, changed: true, idempotent: false };
  });
  try {
    await auth.revokeRefreshTokens(input.targetUid);
  } catch {
    // Firestore remains authoritative. Retrying the same request retries Auth.
    return { ...result, tokenRevocationPending: true };
  }
  return { ...result, tokenRevocationPending: false };
}

export async function revokeAccountEnforcement(firestore, auth, input, now = new Date()) {
  assertSafeFirestore(firestore);
  validateCommon(input);
  const enforcementRef = firestore.collection(ACCOUNT_ENFORCEMENT).doc(input.targetUid);
  const auditRef = firestore.collection(MODERATION_ACTIONS).doc(actionId('revoke', input));
  const result = await firestore.runTransaction(async (transaction) => {
    const [current, audit] = await transaction.getAll(enforcementRef, auditRef);
    if (audit.exists) {
      if (audit.data().targetUid !== input.targetUid || audit.data().actorUid !== input.actorUid) {
        throw new HttpsError('failed-precondition', 'Enforcement request conflict.');
      }
      return { revoked: true, changed: false, idempotent: true };
    }
    if (!current.exists) return { revoked: true, changed: false, idempotent: true };
    const data = current.data();
    const status = data.status === 'suspended' ? 'suspended' : 'banned';
    transaction.create(auditRef, {
      schemaVersion: ENFORCEMENT_SCHEMA_VERSION,
      type: status === 'suspended' ? 'suspension_revoked' : 'ban_revoked',
      targetUid: input.targetUid,
      actorUid: input.actorUid,
      reasonCode: ENFORCEMENT_REASONS.includes(data.reasonCode)
        ? data.reasonCode : 'other_policy_violation',
      sourceReportIds: Array.isArray(data.sourceReportIds) ? data.sourceReportIds : [],
      createdAt: now,
      requestId: input.requestId,
      previousStatus: status,
      newStatus: 'none',
      ...(data.expiresAt ? { previousExpiresAt: data.expiresAt } : {}),
    });
    transaction.delete(enforcementRef);
    return { revoked: true, changed: true, idempotent: false };
  });
  try {
    await auth.revokeRefreshTokens(input.targetUid);
  } catch {
    return { ...result, tokenRevocationPending: true };
  }
  return { ...result, tokenRevocationPending: false };
}

export async function getAccountAccessStateOperation(firestore, request, now = new Date()) {
  const uid = request?.auth?.uid;
  if (!validId(uid)) throw new HttpsError('unauthenticated', 'Authentication required.');
  const enforcement = await readEffectiveAccountEnforcement(firestore, uid, now);
  if (!enforcement) return { restricted: false };
  return {
    restricted: true,
    status: enforcement.status,
    reasonCategory: enforcement.reasonCode,
    ...(enforcement.status === 'suspended' ? { expiresAt: enforcement.expiresAt } : {}),
  };
}
