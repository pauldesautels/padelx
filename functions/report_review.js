import { createHash } from 'node:crypto';
import { HttpsError } from 'firebase-functions/v2/https';
import { assertSafeFirestore } from './backend_environment.js';
import { MODERATION_ACTIONS } from './account_enforcement.js';
import {
  REPORT_ACTIONED_OUTCOME, validateActionInput, validateDismissalInput,
  validateReviewContext, validReportId,
} from './report_review_policy.js';

const REVIEW_LIMIT_MAX = 25;
const millis = (value) => value instanceof Date ? value.getTime() : value?.toMillis?.();
const auditId = (type, input) => createHash('sha256')
  .update(`report-review\0${type}\0${input.actorUid}\0${input.reportId}\0${input.requestId}`)
  .digest('hex');
const failed = (message) => new HttpsError('failed-precondition', message);

function requireReport(snapshot) {
  if (!snapshot.exists) throw new HttpsError('not-found', 'Report unavailable.');
  return snapshot.data();
}

function assertOwner(data, actorUid) {
  if (data.status === 'reviewing' && data.reviewerUid !== actorUid) {
    throw new HttpsError('permission-denied', 'Report belongs to another reviewer.');
  }
}

function replayMatches(audit, expected) {
  return Object.entries(expected).every(([key, value]) => audit[key] === value);
}

async function transition(firestore, input, type, nextStatus, options = {}, now = new Date()) {
  assertSafeFirestore(firestore);
  const reportRef = firestore.doc(`reports/${input.reportId}`);
  const auditRef = firestore.doc(`${MODERATION_ACTIONS}/${auditId(type, input)}`);
  return firestore.runTransaction(async (transaction) => {
    const refs = [reportRef, auditRef];
    if (options.actionRef) refs.push(options.actionRef);
    const [reportSnapshot, auditSnapshot, actionSnapshot] = await transaction.getAll(...refs);
    const expectedAudit = {
      type, reportId: input.reportId, actorUid: input.actorUid,
      requestId: input.requestId, newStatus: nextStatus,
      ...(options.outcomeCode ? { outcomeCode: options.outcomeCode } : {}),
      ...(input.resolutionActionId ? { resolutionActionId: input.resolutionActionId } : {}),
    };
    if (auditSnapshot.exists) {
      if (!replayMatches(auditSnapshot.data(), expectedAudit) || options.replayValidate?.(reportSnapshot.data()) === false) {
        throw failed('Review request conflict.');
      }
      return { changed: false, idempotent: true, status: nextStatus };
    }
    const data = requireReport(reportSnapshot);
    options.validate?.(data, actionSnapshot);
    const update = options.buildReplacement
      ? options.buildReplacement(data, { status: nextStatus, updatedAt: now })
      : { status: nextStatus, updatedAt: now, ...options.update };
    if (options.buildReplacement) transaction.set(reportRef, update);
    else transaction.update(reportRef, update);
    transaction.create(auditRef, {
      schemaVersion: 1, ...expectedAudit, previousStatus: data.status, createdAt: now,
    });
    return { changed: true, idempotent: false, status: nextStatus };
  });
}

export async function listReportsForReview(firestore, { status, urgent = false, limit = 25 }) {
  assertSafeFirestore(firestore);
  if (!['open', 'reviewing'].includes(status) || !Number.isInteger(limit)
      || limit < 1 || limit > REVIEW_LIMIT_MAX || (urgent && status !== 'open')) {
    throw new HttpsError('invalid-argument', 'Invalid report queue.');
  }
  let query = firestore.collection('reports').where('status', '==', status);
  if (urgent) query = query.where('reason', '==', 'threats_unsafe_behavior');
  const snapshot = await query.orderBy('createdAt', 'asc').limit(limit).get();
  return snapshot.docs.map((document) => {
    const data = document.data();
    return {
      id: document.id, status: data.status, subjectType: data.subjectType,
      subjectId: data.subjectId, reason: data.reason, createdAt: data.createdAt,
      ...(data.reviewStartedAt ? { reviewStartedAt: data.reviewStartedAt } : {}),
    };
  });
}

export async function getReportForReview(firestore, reportId) {
  assertSafeFirestore(firestore);
  if (!validReportId(reportId)) throw new HttpsError('invalid-argument', 'Invalid report ID.');
  const snapshot = await firestore.doc(`reports/${reportId}`).get();
  return { id: snapshot.id, ...requireReport(snapshot) };
}

export async function startReportReview(firestore, rawInput, now = new Date()) {
  const input = validateReviewContext(rawInput);
  return transition(firestore, input, 'report_review_started', 'reviewing', {
    validate(data) {
      if (data.status !== 'open' || data.resolvedAt !== undefined) {
        throw failed('Only an unresolved open report can be claimed.');
      }
    },
    update: { reviewerUid: input.actorUid, reviewStartedAt: now },
  }, now);
}

export async function releaseReportReview(firestore, rawInput, now = new Date()) {
  const input = validateReviewContext(rawInput);
  return transition(firestore, input, 'report_review_released', 'open', {
    validate(data) {
      if (data.status !== 'reviewing' || data.resolvedAt !== undefined) {
        throw failed('Only an unresolved reviewing report can be released.');
      }
      assertOwner(data, input.actorUid);
    },
    buildReplacement(data, required) {
      const released = { ...data, ...required };
      delete released.reviewerUid;
      delete released.reviewStartedAt;
      return released;
    },
  }, now);
}

export async function dismissReport(firestore, rawInput, now = new Date()) {
  const input = validateDismissalInput(rawInput);
  return transition(firestore, input, 'report_dismissed', 'dismissed', {
    outcomeCode: input.outcomeCode,
    validate(data) {
      if (!['open', 'reviewing'].includes(data.status)) throw failed('Resolved reports are immutable.');
      if (data.resolvedAt !== undefined) throw failed('Report resolution is immutable.');
      assertOwner(data, input.actorUid);
    },
    update: {
      reviewerUid: input.actorUid, resolvedAt: now, outcomeCode: input.outcomeCode,
      ...(input.moderatorNote ? { moderatorNote: input.moderatorNote } : {}),
    },
    replayValidate: (data) => data?.status === 'dismissed'
      && data.outcomeCode === input.outcomeCode
      && data.moderatorNote === input.moderatorNote,
  }, now);
}

export async function markReportActioned(firestore, rawInput, now = new Date()) {
  const input = validateActionInput(rawInput);
  const actionRef = firestore.doc(`${MODERATION_ACTIONS}/${input.resolutionActionId}`);
  return transition(firestore, input, 'report_actioned', 'actioned', {
    actionRef, outcomeCode: REPORT_ACTIONED_OUTCOME,
    validate(data, actionSnapshot) {
      if (!['open', 'reviewing'].includes(data.status)) throw failed('Resolved reports are immutable.');
      if (data.resolvedAt !== undefined) throw failed('Report resolution is immutable.');
      assertOwner(data, input.actorUid);
      if (!actionSnapshot?.exists) throw failed('Moderation action unavailable.');
      const action = actionSnapshot.data();
      if (!['suspension_applied', 'ban_applied'].includes(action.type)
          || action.targetUid !== data.subjectOwnerUid
          || !Array.isArray(action.sourceReportIds)
          || !action.sourceReportIds.includes(input.reportId)) {
        throw failed('Moderation action does not resolve this report.');
      }
    },
    update: {
      reviewerUid: input.actorUid, resolvedAt: now,
      outcomeCode: REPORT_ACTIONED_OUTCOME,
      resolutionActionId: input.resolutionActionId,
      ...(input.moderatorNote ? { moderatorNote: input.moderatorNote } : {}),
    },
    replayValidate: (data) => data?.status === 'actioned'
      && data.resolutionActionId === input.resolutionActionId
      && data.moderatorNote === input.moderatorNote,
  }, now);
}

export const reportReviewAuditId = auditId;
export const timestampMillis = millis;
