import { createHash } from 'node:crypto';

export const redactedReference = (value) => `ref-${createHash('sha256')
  .update(`padelx-safety\0${value ?? ''}`).digest('hex').slice(0, 10)}`;
export const isoTime = (value) => {
  const date = value?.toDate?.() ?? value;
  return date instanceof Date && Number.isFinite(date.getTime()) ? date.toISOString() : 'unavailable';
};

export function listRow(report) {
  return {
    reportId: report.id, status: report.status, subjectType: report.subjectType,
    reason: report.reason, createdAt: isoTime(report.createdAt),
    ...(report.reviewStartedAt ? { reviewStartedAt: isoTime(report.reviewStartedAt) } : {}),
    subjectReference: redactedReference(report.subjectId),
    urgent: report.reason === 'threats_unsafe_behavior',
  };
}

export function reportSummary(report, { showSensitive = false, showReporterUid = false } = {}) {
  const evidence = report.evidence ?? {};
  const output = {
    reportId: report.id, status: report.status, subjectType: report.subjectType,
    reason: report.reason, createdAt: isoTime(report.createdAt),
    subjectReference: redactedReference(report.subjectId),
    reporterReference: redactedReference(report.reporterUid),
    reviewerReference: report.reviewerUid ? redactedReference(report.reviewerUid) : undefined,
    conversationType: report.conversationType,
    hasDetails: typeof report.details === 'string' && report.details.length > 0,
    hasMessageEvidence: typeof evidence.text === 'string',
    publicProfileSnapshot: report.subjectType === 'player' ? {
      displayName: evidence.displayName, avatarVersion: evidence.avatarVersion,
    } : undefined,
    matchSnapshot: report.subjectType === 'match' ? {
      title: evidence.title, clubName: evidence.clubName,
      scheduledAt: isoTime(evidence.scheduledAt), city: evidence.city,
      countryCode: evidence.countryCode, area: evidence.area,
    } : undefined,
    ...(showReporterUid ? { reporterUid: report.reporterUid } : {}),
    ...(showSensitive ? { details: report.details, messageText: evidence.text } : {}),
  };
  return Object.fromEntries(Object.entries(output).filter(([, value]) => value !== undefined));
}
