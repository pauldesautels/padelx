import test from 'node:test';
import assert from 'node:assert/strict';
import { boundedCount, OPERATIONAL_PROJECT, OPERATIONAL_QUERY_LIMIT,
  parseOperationalArguments, requireOperationalCommand, requireOperationalProject,
  safeFailure } from '../tool/operations/policy.mjs';
import { collectOperationalHealth } from '../tool/operations/health.mjs';

test('operational tooling requires dual staging confirmation and rejects production', () => {
  assert.equal(requireOperationalProject({ project: OPERATIONAL_PROJECT,
    'confirm-project': OPERATIONAL_PROJECT }, {}), OPERATIONAL_PROJECT);
  assert.throws(() => requireOperationalProject({ project: 'padelx-f168f',
    'confirm-project': 'padelx-f168f' }, {}), /Production is prohibited/);
  assert.throws(() => requireOperationalProject({ project: OPERATIONAL_PROJECT }, {}),
    /matching staging/);
  assert.throws(() => requireOperationalProject({ project: OPERATIONAL_PROJECT,
    'confirm-project': OPERATIONAL_PROJECT }, { GOOGLE_CLOUD_PROJECT: 'other' }), /does not match/);
});

test('commands are read-only allowlisted and arguments do not imply mutation', () => {
  const parsed = parseOperationalArguments(['attendance', '--project=padelx-staging', '--apply']);
  assert.equal(requireOperationalCommand(parsed.positionals), 'attendance');
  assert.equal(parsed.options.apply, true);
  assert.throws(() => requireOperationalCommand(['repair']), /Unknown/);
});

test('counts are bounded and disclose only aggregate truncation', () => {
  assert.deepEqual(boundedCount({ size: 3 }), { count: 3, truncated: false });
  assert.deepEqual(boundedCount({ size: OPERATIONAL_QUERY_LIMIT }),
    { count: OPERATIONAL_QUERY_LIMIT, truncated: true });
});

test('failures expose only a bounded category', () => {
  assert.deepEqual(safeFailure({ code: '9-failed-precondition',
    message: 'token private address evidence' }), { status: 'unavailable', code: 'failed-precondition' });
  assert.deepEqual(safeFailure(new Error('secret')), { status: 'unavailable', code: 'unknown' });
  assert.deepEqual(safeFailure({ code: 'token private address evidence' }),
    { status: 'unavailable', code: 'unknown' });
  assert.deepEqual(safeFailure(new Error('Production is prohibited.')),
    { status: 'unavailable', code: 'production-prohibited' });
});

class FakeQuery {
  constructor(rows, failure = null) { this.rows = rows; this.failure = failure; }
  where() { return this; }
  limit(value) { return new FakeQuery(this.rows.slice(0, value), this.failure); }
  async get() {
    if (this.failure) throw this.failure;
    return { size: this.rows.length, docs: this.rows.map((row) => ({ data: () => row })) };
  }
}

test('health output is bounded, aggregate-only, and tolerates a partial failure', async () => {
  const privateFixture = { uid: 'must-not-print', token: 'must-not-print',
    address: 'must-not-print', status: 'new_player', percent: null, sampleSize: 1,
    policyVersion: 'objective-reliability-v2-attendance' };
  const db = { collection: (name) => name === 'pushDeliveryReceipts'
    ? new FakeQuery([], { code: '9-failed-precondition', message: 'private evidence' })
    : new FakeQuery(name === 'reliabilityProfiles' ? [privateFixture] : []) };
  const result = await collectOperationalHealth(db, new Date('2030-01-01T00:00:00Z'));
  const output = JSON.stringify(result);
  assert.equal(result.reliability.status, 'ok');
  assert.equal(result.reliability.newPlayers, 1);
  assert.deepEqual(result.push, { status: 'unavailable', code: 'failed-precondition' });
  for (const secret of ['must-not-print', 'token', 'address', 'private evidence']) {
    assert.equal(output.includes(secret), false);
  }
});

test('health exposes bounded recovery indicators without document identity', async () => {
  const expired = { status: 'active', expiresAt: { toDate: () => new Date('2029-01-01') } };
  const completedWithFailure = { status: 'complete', sentCount: 0, failedCount: 1 };
  const db = { collection: (name) => new FakeQuery(name === 'pushDeliveryReceipts'
    ? [completedWithFailure] : name === 'matchmakingRequests' ? [expired] : []) };
  const result = await collectOperationalHealth(db, new Date('2030-01-01T00:00:00Z'));
  assert.equal(result.matchmaking.overdueRequests.count, 1);
  assert.equal(result.push.completedWithFailures.count, 1);
  assert.equal(result.push.completedWithoutSend.count, 1);
});

test('blocked deletion jobs require operational attention', async () => {
  const db = { collection: (name) => new FakeQuery(name === 'accountDeletionJobs'
    ? [{ status: 'blocked' }] : []) };
  const result = await collectOperationalHealth(db, new Date('2030-01-01T00:00:00Z'));
  assert.equal(result.deletion.status, 'attention');
  assert.equal(result.deletion.blockedJobs.count, 1);
});
