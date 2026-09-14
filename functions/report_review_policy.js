import { HttpsError } from 'firebase-functions/v2/https';

export const REPORT_REVIEW_STATUSES = Object.freeze([
  'open', 'reviewing', 'dismissed', 'actioned',
]);
export const REPORT_DISMISSAL_OUTCOMES = Object.freeze([
  'no_violation', 'insufficient_evidence',
]);
export const REPORT_ACTIONED_OUTCOME = 'violation_confirmed';
export const MODERATOR_NOTE_MAX_CODE_POINTS = 300;
export const REPORT_REVIEW_AUDIT_TYPES = Object.freeze([
  'report_review_started', 'report_review_released', 'report_dismissed',
  'report_actioned', 'safety_role_granted', 'safety_role_revoked',
]);

const unsafeControlCharacters = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/u;
const pathSegment = (value) => typeof value === 'string' && value.length > 0
  && value.length <= 128 && !value.includes('/') && !unsafeControlCharacters.test(value);
const requestId = (value) => typeof value === 'string'
  && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);

function invalid(message) {
  return new HttpsError('invalid-argument', message);
}

export function normalizeModeratorNote(value) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || unsafeControlCharacters.test(value)) {
    throw invalid('Moderator note is invalid.');
  }
  const note = value.trim();
  if ([...note].length > MODERATOR_NOTE_MAX_CODE_POINTS) {
    throw invalid('Moderator note is too long.');
  }
  return note || undefined;
}

export function validateReviewContext(input) {
  if (!input || typeof input !== 'object' || !pathSegment(input.actorUid)
      || !pathSegment(input.reportId) || !requestId(input.requestId)) {
    throw invalid('Valid trusted report-review context required.');
  }
  return input;
}

export function validateDismissalInput(input) {
  validateReviewContext(input);
  if (!REPORT_DISMISSAL_OUTCOMES.includes(input.outcomeCode)) {
    throw invalid('A valid dismissal outcome is required.');
  }
  return { ...input, moderatorNote: normalizeModeratorNote(input.moderatorNote) };
}

export function validateActionInput(input) {
  validateReviewContext(input);
  if (!pathSegment(input.resolutionActionId)) {
    throw invalid('A valid moderation action is required.');
  }
  return { ...input, moderatorNote: normalizeModeratorNote(input.moderatorNote) };
}

export function canTransition(previousStatus, nextStatus, { release = false } = {}) {
  if (previousStatus === 'open') return ['reviewing', 'dismissed', 'actioned'].includes(nextStatus);
  if (previousStatus === 'reviewing') {
    return ['dismissed', 'actioned'].includes(nextStatus) || (release && nextStatus === 'open');
  }
  return false;
}

export function validReportId(value) { return pathSegment(value); }
export function validReviewRequestId(value) { return requestId(value); }
