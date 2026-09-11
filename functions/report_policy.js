import { createHash } from 'node:crypto';
import { HttpsError } from 'firebase-functions/v2/https';
import { validRelationshipUid } from './friendship_policy.js';
import { validRequestId } from './messaging_policy.js';

export const REPORT_SCHEMA_VERSION = 1;
export const REPORT_DETAILS_MAX_LENGTH = 500;
export const REPORT_ROLLING_WINDOW_MS = 24 * 60 * 60 * 1000;
export const REPORT_ROLLING_MAX = 10;
export const REPORT_SUBJECT_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
export const REPORT_REASONS = Object.freeze([
  'harassment_bullying',
  'hate_abuse',
  'sexual_inappropriate',
  'threats_unsafe_behavior',
  'spam_scam',
  'impersonation',
  'other',
]);

const REPORT_TYPES = new Set(['player', 'message', 'match']);
const REPORT_REASON_SET = new Set(REPORT_REASONS);
const REQUEST_KEYS = new Set([
  'requestId', 'subjectType', 'subjectId', 'conversationId', 'reason', 'details',
]);
const unsafeControlCharacters = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/u;
const pathSegment = (value) => typeof value === 'string' && value.length > 0
  && value.length <= 128 && !value.includes('/');
const digest = (value) => createHash('sha256').update(value).digest('hex');

export function normalizeReportPayload(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)
      || Object.keys(data).some((key) => !REQUEST_KEYS.has(key))
      || !validRequestId(data.requestId)
      || !REPORT_TYPES.has(data.subjectType)
      || !REPORT_REASON_SET.has(data.reason)) {
    throw new HttpsError('invalid-argument', 'A valid report is required.');
  }
  const validSubject = data.subjectType === 'player'
    ? validRelationshipUid(data.subjectId) : pathSegment(data.subjectId);
  const messageConversation = data.subjectType === 'message';
  if (!validSubject
      || (messageConversation
        ? typeof data.conversationId !== 'string'
          || !/^(direct|match)_[a-f0-9]{64}$/.test(data.conversationId)
        : data.conversationId !== undefined)) {
    throw new HttpsError('invalid-argument', 'A valid report subject is required.');
  }
  let details;
  if (data.details !== undefined) {
    if (typeof data.details !== 'string' || unsafeControlCharacters.test(data.details)) {
      throw new HttpsError('invalid-argument', 'Report details are invalid.');
    }
    details = data.details.trim();
    if ([...details].length > REPORT_DETAILS_MAX_LENGTH) {
      throw new HttpsError('invalid-argument', 'Report details are too long.');
    }
    if (!details) details = undefined;
  }
  return {
    requestId: data.requestId,
    subjectType: data.subjectType,
    subjectId: data.subjectId,
    ...(messageConversation ? { conversationId: data.conversationId } : {}),
    reason: data.reason,
    ...(details ? { details } : {}),
  };
}

export const reportIdFor = (reporterUid, requestId) =>
  digest(`report\0${reporterUid}\0${requestId}`);

export function reportDedupeKey(reporterUid, payload) {
  const subject = payload.subjectType === 'message'
    ? `${payload.conversationId}\0${payload.subjectId}` : payload.subjectId;
  return digest(`subject\0${reporterUid}\0${payload.subjectType}\0${subject}`);
}

export const reporterRateLimitId = (reporterUid) =>
  `reporter_${digest(reporterUid)}`;

export const subjectRateLimitId = (dedupeKey) => `subject_${dedupeKey}`;
