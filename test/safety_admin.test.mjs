import test from 'node:test';
import assert from 'node:assert/strict';
import { changeRole, requireEnforcer, requireReviewer } from '../tool/safety_admin/authz.mjs';
import { parseArguments, requireMutation, requireSafeProject,
  requireTarget, sourceReportIdsFromOptions } from '../tool/safety_admin/policy.mjs';
import { reportSummary } from '../tool/safety_admin/format.mjs';
import { readFile } from 'node:fs/promises';

test('CLI universally requires explicit matching staging and actor', () => {
  const safe = { project: 'padelx-staging', 'confirm-project': 'padelx-staging',
    'actor-uid': 'actor' };
  assert.equal(requireSafeProject(safe, {}).projectId, 'padelx-staging');
  for (const options of [
    {}, { ...safe, project: 'padelx-f168f' }, { ...safe, 'confirm-project': 'other' },
    { ...safe, project: 'other', 'confirm-project': 'other' }, { ...safe, 'actor-uid': undefined },
  ]) assert.throws(() => requireSafeProject(options, {}));
  assert.throws(() => requireSafeProject(safe, { FIRESTORE_EMULATOR_HOST: 'localhost:8080' }));
  assert.throws(() => requireSafeProject(safe, { GCLOUD_PROJECT: 'padelx-f168f' }));
});

test('mutations require apply, UUID, and exact target confirmation', () => {
  assert.throws(() => requireMutation({}));
  assert.throws(() => requireMutation({ apply: true, 'request-id': 'short' }));
  assert.equal(requireMutation({ apply: true,
    'request-id': '123e4567-e89b-42d3-a456-426614174000' }).length, 36);
  assert.throws(() => requireTarget({ 'target-uid': 'one', 'confirm-target-uid': 'two' }));
  assert.equal(requireTarget({ 'confirm-target-uid': 'one' }, 'one'), 'one');
  assert.deepEqual(parseArguments(['reports', 'show', 'abc', '--apply']), {
    positionals: ['reports', 'show', 'abc'], options: { apply: true },
  });
});

test('enforcement source report flags support singular, bounded multiple, and no source', () => {
  assert.deepEqual(sourceReportIdsFromOptions({ 'source-report-id': 'report-one' }), ['report-one']);
  assert.deepEqual(sourceReportIdsFromOptions({
    'source-report-id': 'report-one', 'source-report-ids': 'report-two,report-one',
  }), ['report-one', 'report-two']);
  assert.deepEqual(sourceReportIdsFromOptions({}), []);
  assert.throws(() => sourceReportIdsFromOptions({
    'source-report-ids': Array.from({ length: 21 }, (_, index) => `report-${index}`).join(','),
  }));
  assert.throws(() => sourceReportIdsFromOptions({ 'source-report-id': 'bad/report' }));
});

test('roles are independent and fake profile data has no effect', () => {
  assert.doesNotThrow(() => requireReviewer({ claims: { safetyReviewer: true } }));
  assert.throws(() => requireEnforcer({ claims: { safetyReviewer: true, moderator: true } }));
  assert.doesNotThrow(() => requireEnforcer({ claims: { safetyEnforcer: true } }));
  assert.throws(() => requireReviewer({ claims: { safetyEnforcer: true } }));
});

test('default report formatting redacts identity and suppresses evidence', () => {
  const report = { id: 'report', status: 'open', subjectType: 'message',
    subjectId: 'message', reporterUid: 'raw-reporter', reason: 'other',
    createdAt: new Date('2030-01-01'), details: 'private', evidence: { text: 'private text' } };
  const safe = reportSummary(report);
  assert.equal(safe.reporterUid, undefined);
  assert.equal(safe.details, undefined);
  assert.equal(safe.messageText, undefined);
  assert.match(safe.reporterReference, /^ref-/);
  assert.equal(reportSummary(report, { showSensitive: true }).messageText, 'private text');
});

test('role changes preserve unrelated claims, verify, revoke tokens, and audit', async () => {
  const state = { customClaims: { unrelated: 'kept' } };
  const auth = {
    revoked: 0,
    async getUser() { return state; },
    async setCustomUserClaims(_uid, claims) { state.customClaims = claims; },
    async revokeRefreshTokens() { this.revoked++; },
  };
  const records = new Map();
  const firestore = { doc(path) { return {
    async get() { return { exists: records.has(path), data: () => records.get(path) }; },
    async create(data) { records.set(path, data); },
  }; } };
  const common = { firestore, auth, actorUid: 'actor', targetUid: 'target',
    role: 'reviewer', requestId: '123e4567-e89b-42d3-a456-426614174000' };
  await changeRole({ ...common, grant: true });
  assert.equal(state.customClaims.unrelated, 'kept');
  assert.equal(state.customClaims.safetyReviewer, true);
  assert.equal(auth.revoked, 1);
  assert.equal(records.size, 1);
  await changeRole({ ...common, grant: true });
  assert.equal(auth.revoked, 1);
});

test('report review and role operations are not exported as Cloud Functions', async () => {
  const source = await readFile(new URL('../functions/index.js', import.meta.url), 'utf8');
  for (const privileged of [
    'listReportsForReview', 'getReportForReview', 'startReportReview',
    'releaseReportReview', 'dismissReport', 'markReportActioned',
    'applyAccountEnforcement', 'revokeAccountEnforcement',
  ]) assert.doesNotMatch(source, new RegExp(`export const ${privileged}\\b`));
});
