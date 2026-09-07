import test from 'node:test';
import assert from 'node:assert/strict';
import { ACCOUNT_SCHEMA_VERSION, CURRENT_DELETION_SCHEMA_VERSION, deletionPhasesFor,
  deletionStateFor } from '../functions/account_state.js';
import { DELETION_WORKER_PHASES, DELETION_WORKER_PHASES_V2 } from '../functions/account_deletion_worker.js';

test('new deletion jobs are pinned to schema v2', () => {
  const state = deletionStateFor('user-a', new Date('2026-01-01T00:00:00Z'), 2);
  assert.equal(ACCOUNT_SCHEMA_VERSION, 1);
  assert.equal(CURRENT_DELETION_SCHEMA_VERSION, 2);
  assert.equal(state.job.schemaVersion, 2);
  assert.equal(state.barrier.schemaVersion, 2);
});

test('schema v1 phase order remains unchanged', () => {
  assert.deepEqual(DELETION_WORKER_PHASES,
    ['accepted', 'matches', 'joinRequests', 'notifications', 'ratings', 'verify', 'deleteAuth']);
  assert.deepEqual(deletionPhasesFor(1), DELETION_WORKER_PHASES);
});

test('schema v2 has explicit social, messaging, and storage phases', () => {
  assert.deepEqual(DELETION_WORKER_PHASES_V2,
    ['accepted', 'matches', 'joinRequests', 'social', 'messaging', 'notifications',
      'ratings', 'storage', 'verify', 'deleteAuth']);
  assert.throws(() => deletionPhasesFor(3), /Unsupported/);
});
