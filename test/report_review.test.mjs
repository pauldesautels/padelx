import { after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import {
  dismissReport, getReportForReview, listReportsForReview, markReportActioned,
  releaseReportReview, startReportReview,
} from '../functions/report_review.js';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Firestore emulator is required');
const projectId = 'demo-padelx-review';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= '127.0.0.1:9099';
const app = initializeApp({ projectId }, 'report-review-tests');
const db = getFirestore(app);
after(() => deleteApp(app));
beforeEach(async () => {
  for (const name of ['reports', 'moderationActions']) {
    const docs = await db.collection(name).listDocuments();
    await Promise.all(docs.map((document) => document.delete()));
  }
});

const now = new Date('2030-01-01T12:00:00Z');
const later = new Date('2030-01-01T13:00:00Z');
const requestId = (suffix) => `123e4567-e89b-42d3-a456-4266141740${suffix}`;
const input = (reportId, actorUid = 'reviewer-one', suffix = '00') => ({
  reportId, actorUid, requestId: requestId(suffix),
});
async function seedReport(id, overrides = {}) {
  await db.doc(`reports/${id}`).set({ schemaVersion: 1, reporterUid: 'reporter',
    subjectType: 'player', subjectId: 'target', subjectOwnerUid: 'target',
    reason: 'harassment_bullying', status: 'open', createdAt: now, updatedAt: now,
    evidence: { displayName: 'Snapshot' }, ...overrides });
}

test('queues are oldest first, limited, urgent, and omit evidence', async () => {
  await seedReport('later', { createdAt: later });
  await seedReport('urgent', { reason: 'threats_unsafe_behavior' });
  const open = await listReportsForReview(db, { status: 'open' });
  assert.deepEqual(open.map((report) => report.id), ['urgent', 'later']);
  assert.equal('evidence' in open[0], false);
  assert.deepEqual((await listReportsForReview(db,
    { status: 'open', urgent: true })).map((report) => report.id), ['urgent']);
  await assert.rejects(() => listReportsForReview(db, { status: 'open', limit: 26 }));
});

test('start and release are owner-only, audited, idempotent, and preserve evidence', async () => {
  await seedReport('report-one');
  const first = await startReportReview(db, input('report-one'), now);
  assert.equal(first.changed, true);
  assert.equal((await getReportForReview(db, 'report-one')).reviewerUid, 'reviewer-one');
  assert.equal((await startReportReview(db, input('report-one'), now)).idempotent, true);
  await assert.rejects(startReportReview(db, input('report-one', 'reviewer-two', '01'), now),
    { code: 'failed-precondition' });
  await assert.rejects(releaseReportReview(db, input('report-one', 'reviewer-two', '02'), later),
    { code: 'permission-denied' });
  await releaseReportReview(db, input('report-one', 'reviewer-one', '03'), later);
  const released = await getReportForReview(db, 'report-one');
  assert.equal(released.status, 'open');
  assert.deepEqual(released.evidence, { displayName: 'Snapshot' });
  assert.equal((await db.collection('moderationActions').get()).size, 2);
});

test('open and owned reviewing reports can be dismissed but never reopened', async () => {
  await seedReport('open-report');
  await dismissReport(db, { ...input('open-report'), outcomeCode: 'no_violation',
    moderatorNote: '  reviewed  ' }, later);
  const dismissed = await getReportForReview(db, 'open-report');
  assert.equal(dismissed.status, 'dismissed');
  assert.equal(dismissed.moderatorNote, 'reviewed');
  assert.equal(dismissed.resolvedAt.toMillis(), later.getTime());
  assert.equal((await dismissReport(db, { ...input('open-report'), outcomeCode: 'no_violation',
    moderatorNote: 'reviewed' }, later)).idempotent, true);
  await assert.rejects(dismissReport(db, { ...input('open-report'), outcomeCode: 'no_violation',
    moderatorNote: 'different' }, later), { code: 'failed-precondition' });
  await assert.rejects(startReportReview(db, input('open-report', 'reviewer-one', '01'), later));

  await seedReport('owned');
  await startReportReview(db, input('owned', 'reviewer-one', '02'), now);
  await assert.rejects(dismissReport(db, { ...input('owned', 'reviewer-two', '03'),
    outcomeCode: 'insufficient_evidence' }, later), { code: 'permission-denied' });
  await dismissReport(db, { ...input('owned', 'reviewer-one', '04'),
    outcomeCode: 'insufficient_evidence' }, later);
});

test('resolvedAt blocks malformed reopen/release attempts and remains immutable', async () => {
  await seedReport('malformed-open', { resolvedAt: now });
  await assert.rejects(startReportReview(db, input('malformed-open'), later),
    { code: 'failed-precondition' });
  await seedReport('malformed-reviewing', { status: 'reviewing', reviewerUid: 'reviewer-one',
    reviewStartedAt: now, resolvedAt: now });
  await assert.rejects(releaseReportReview(db, input('malformed-reviewing'), later),
    { code: 'failed-precondition' });
  assert.equal((await getReportForReview(db, 'malformed-open')).resolvedAt.toMillis(), now.getTime());
});

test('action resolution verifies enforcement type, target, and source linkage', async () => {
  for (const [id, type] of [['suspended', 'suspension_applied'], ['banned', 'ban_applied']]) {
    const reportId = `report-${id}`;
    await seedReport(reportId);
    await db.doc(`moderationActions/action-${id}`).set({
      schemaVersion: 1, type, targetUid: 'target', sourceReportIds: [reportId], createdAt: now,
    });
    await markReportActioned(db, { ...input(reportId, 'reviewer-one', id === 'suspended' ? '05' : '06'),
      resolutionActionId: `action-${id}` }, later);
    const report = await getReportForReview(db, reportId);
    assert.equal(report.status, 'actioned');
    assert.equal(report.outcomeCode, 'violation_confirmed');
  }
  for (const [id, action] of [
    ['wrong-target', { type: 'ban_applied', targetUid: 'other', sourceReportIds: ['wrong-target'] }],
    ['wrong-link', { type: 'ban_applied', targetUid: 'target', sourceReportIds: ['other'] }],
    ['wrong-type', { type: 'ban_revoked', targetUid: 'target', sourceReportIds: ['wrong-type'] }],
  ]) {
    await seedReport(id);
    await db.doc(`moderationActions/action-${id}`).set(action);
    await assert.rejects(markReportActioned(db, { ...input(id, 'reviewer-one', '07'),
      resolutionActionId: `action-${id}` }, later), { code: 'failed-precondition' });
  }
});

test('report submission data remains unchanged except additive review metadata', async () => {
  await seedReport('evidence-report', { details: 'original detail', evidence: { text: 'snapshot' } });
  await dismissReport(db, { ...input('evidence-report'), outcomeCode: 'no_violation' }, later);
  const report = await getReportForReview(db, 'evidence-report');
  assert.equal(report.schemaVersion, 1);
  assert.equal(report.details, 'original detail');
  assert.deepEqual(report.evidence, { text: 'snapshot' });
});
