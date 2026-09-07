import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, unlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { classifyCompositeIndexes, indexCheckerOptions, parseIndexManifest } from '../tool/check_phase9_indexes.mjs';
import { loadCheckpoint, runMigration } from '../tool/migrate_phase9.mjs';
import { advanceCheckpoint, migrationOptions, parseCheckpoint, phase9ProfilePatch,
  publicSummary, establishOperatorProjectEnvironment } from '../tool/phase9_tool_policy.mjs';
import { assertContributionAccountingReady, assertPhase9Enabled, assertPlayedWithProjectionReady,
  backendEnvironment } from '../functions/backend_environment.js';

test('index checker parses manifests and classifies missing, wrong-scope, creating, and ready indexes', () => {
  const spec = parseIndexManifest(JSON.stringify({ indexes: [{ collectionGroup: 'items', queryScope: 'COLLECTION',
    fields: [{ fieldPath: 'uid', order: 'ASCENDING' }] }], fieldOverrides: [] }));
  assert.equal(classifyCompositeIndexes(spec, [])[0].status, 'missing');
  assert.equal(classifyCompositeIndexes(spec, [{ collectionGroup: 'items', queryScope: 'COLLECTION_GROUP',
    fields: [{ fieldPath: 'uid', order: 'ASCENDING' }], state: 'READY' }])[0].status, 'missing');
  for (const state of ['CREATING', 'READY']) assert.equal(classifyCompositeIndexes(spec, [{ collectionGroup: 'items',
    queryScope: 'COLLECTION', fields: [{ fieldPath: 'uid', order: 'ASCENDING' }], state }])[0].status, state);
  assert.throws(() => parseIndexManifest('{}'), /Malformed/);
  assert.throws(() => classifyCompositeIndexes(spec, {}), /Malformed/);
  assert.throws(() => indexCheckerOptions(['--project=padelx-f168f']), /refuses/);
});

test('backfill policy is dry-run, staging-only, bounded, private-data-free, and deterministic', () => {
  assert.deepEqual(migrationOptions(['--project=padelx-staging']), {
    projectId: 'padelx-staging', apply: false, validateOnly: false, pageSize: 50,
    checkpointPath: '.phase9-backfill-checkpoint.json' });
  assert.equal(migrationOptions(['--project=padelx-staging', '--apply']).apply, true);
  assert.throws(() => migrationOptions(['--project=padelx-staging', '--checkpoint']), /local file path/);
  for (const value of ['0', '101', '1.5']) assert.throws(() => migrationOptions([
    '--project=padelx-staging', `--page-size=${value}`]), /1\.\.100/);
  assert.throws(() => migrationOptions(['--project=padelx-f168f']), /refuses/);
  const first = phase9ProfilePatch({ email: 'private@example.com' }, {});
  const replay = phase9ProfilePatch(first, first);
  assert.deepEqual(replay, first); assert.equal(first.discoverable, false); assert.equal(first.avatarVersion, 0);
  assert.equal('email' in first, false); assert.equal('friendship' in first, false); assert.equal('message' in first, false);
  assert.equal(publicSummary({ mode: 'DRY RUN', scanned: 1 }).includes('private@example.com'), false);
  const saved = advanceCheckpoint({ stage: 'profiles', usersAfter: null }, ['a', 'b'], 2);
  assert.deepEqual(saved, { stage: 'profiles', usersAfter: 'b', matchesAfter: null });
  assert.deepEqual(advanceCheckpoint(saved, [], 2), { stage: 'matches', usersAfter: null, matchesAfter: null });
  assert.deepEqual(phase9ProfilePatch(first, first), phase9ProfilePatch(replay, replay),
    'a replayed page produces the same writes');
});

test('operator project establishes an unambiguous staging context and conflicts fail closed', () => {
  const env = {};
  establishOperatorProjectEnvironment('padelx-staging', env);
  assert.deepEqual(backendEnvironment(env), { projectId: 'padelx-staging', mode: 'staging' });
  assert.equal(env.GCLOUD_PROJECT, 'padelx-staging');
  assert.equal(env.GOOGLE_CLOUD_PROJECT, 'padelx-staging');
  assert.equal(JSON.parse(env.FIREBASE_CONFIG).projectId, 'padelx-staging');
  assert.throws(() => establishOperatorProjectEnvironment('padelx-staging', {
    GCLOUD_PROJECT: 'demo-selected-by-firebase-use',
  }), /Missing or conflicting/);
  assert.throws(() => establishOperatorProjectEnvironment('padelx-f168f', {}), /refuses/);
  assert.throws(() => backendEnvironment({}), /Missing or conflicting/,
    'the Functions/runtime path retains its missing-environment fail-closed behavior');
});

function fakeFirestore(collections) {
  const writes = { batchSets: 0, commits: 0, reconciles: 0 };
  const db = {
    collection(name) {
      let after = null; let limit = 50;
      const query = {
        orderBy() { return query; },
        limit(value) { limit = value; return query; },
        startAfter(value) { after = value; return query; },
        async get() {
          const start = after === null ? 0 : collections[name].findIndex((item) => item.id === after) + 1;
          const docs = collections[name].slice(start, start + limit).map((item) => ({
            id: item.id, ref: { path: `${name}/${item.id}` }, data: () => item.data ?? {},
          }));
          return { docs, size: docs.length, empty: docs.length === 0 };
        },
      };
      return query;
    },
    doc(path) { return { path, get: async () => ({ data: () => ({}) }) }; },
    batch() { return { set() { writes.batchSets += 1; }, async commit() { writes.commits += 1; } }; },
  };
  return { db, writes, reconcile: async () => { writes.reconciles += 1; } };
}

test('dry-run persists only local progress, resumes the next stage, and deletion restarts it', async (context) => {
  const directory = await mkdtemp(join(tmpdir(), 'phase9-checkpoint-'));
  context.after(() => rm(directory, { recursive: true, force: true }));
  const checkpointPath = join(directory, 'checkpoint.json');
  const fake = fakeFirestore({
    users: [{ id: 'u1' }, { id: 'u2' }], matches: [{ id: 'm1' }],
  });
  const options = migrationOptions(['--project=padelx-staging', '--page-size=50',
    `--checkpoint=${checkpointPath}`]);

  const first = await runMigration(options, fake);
  assert.deepEqual(first, { mode: 'DRY RUN', project: 'padelx-staging', scanned: 2,
    wouldWrite: 4, written: 0, invalid: 2, nextStage: 'matches' });
  assert.equal(JSON.parse(await readFile(checkpointPath, 'utf8')).stage, 'matches');
  assert.deepEqual(fake.writes, { batchSets: 0, commits: 0, reconciles: 0 });

  const second = await runMigration(options, fake);
  assert.equal(second.scanned, 1); assert.equal(second.wouldWrite, 1);
  assert.equal(second.written, 0); assert.equal(second.nextStage, 'complete');
  assert.deepEqual(fake.writes, { batchSets: 0, commits: 0, reconciles: 0 });

  await unlink(checkpointPath);
  const restarted = await runMigration(options, fake);
  assert.equal(restarted.scanned, 2); assert.equal(restarted.nextStage, 'matches');
});

test('--apply still performs remote writes and persists local progress', async (context) => {
  const directory = await mkdtemp(join(tmpdir(), 'phase9-checkpoint-'));
  context.after(() => rm(directory, { recursive: true, force: true }));
  const checkpointPath = join(directory, 'checkpoint.json');
  const fake = fakeFirestore({ users: [{ id: 'u1' }], matches: [{ id: 'm1' }] });
  const result = await runMigration(migrationOptions(['--project=padelx-staging', '--apply',
    `--checkpoint=${checkpointPath}`]), fake);
  assert.equal(result.written, 2); assert.equal(result.nextStage, 'matches');
  assert.deepEqual(fake.writes, { batchSets: 2, commits: 1, reconciles: 0 });
  assert.equal((await loadCheckpoint(checkpointPath)).stage, 'matches');
  const matches = await runMigration(migrationOptions(['--project=padelx-staging', '--apply',
    `--checkpoint=${checkpointPath}`]), fake);
  assert.equal(matches.written, 1); assert.equal(matches.nextStage, 'complete');
  assert.deepEqual(fake.writes, { batchSets: 2, commits: 1, reconciles: 1 });
});

test('matches-stage apply establishes context before reconciliation, preserves failure progress, and replays', async (context) => {
  const directory = await mkdtemp(join(tmpdir(), 'phase9-checkpoint-'));
  context.after(() => rm(directory, { recursive: true, force: true }));
  const checkpointPath = join(directory, 'checkpoint.json');
  const checkpoint = { stage: 'matches', usersAfter: null, matchesAfter: null };
  await writeFile(checkpointPath, JSON.stringify(checkpoint));
  const fake = fakeFirestore({ users: [], matches: [{ id: 'm1' }] });
  const options = migrationOptions(['--project=padelx-staging', '--apply', `--checkpoint=${checkpointPath}`]);
  const prior = {
    GCLOUD_PROJECT: process.env.GCLOUD_PROJECT,
    GOOGLE_CLOUD_PROJECT: process.env.GOOGLE_CLOUD_PROJECT,
    FIREBASE_CONFIG: process.env.FIREBASE_CONFIG,
  };
  const restore = () => {
    for (const [key, value] of Object.entries(prior)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
  };
  context.after(restore);
  delete process.env.GCLOUD_PROJECT;
  delete process.env.GOOGLE_CLOUD_PROJECT;
  delete process.env.FIREBASE_CONFIG;

  let attempts = 0;
  await assert.rejects(runMigration(options, { db: fake.db, reconcile: async () => {
    attempts += 1;
    assert.deepEqual(backendEnvironment(), { projectId: 'padelx-staging', mode: 'staging' });
    throw new Error('pre-write failure');
  } }), /pre-write failure/);
  assert.equal(attempts, 1);
  assert.deepEqual(JSON.parse(await readFile(checkpointPath, 'utf8')), checkpoint,
    'a failed reconciliation does not advance or rewrite the checkpoint');

  const applied = new Set();
  const replaySafe = async (_db, matchId) => { applied.add(matchId); };
  const resumed = await runMigration(options, { db: fake.db, reconcile: replaySafe });
  assert.equal(resumed.written, 1);
  assert.deepEqual([...applied], ['m1']);
  await writeFile(checkpointPath, JSON.stringify(checkpoint));
  const replayed = await runMigration(options, { db: fake.db, reconcile: replaySafe });
  assert.equal(replayed.written, 1);
  assert.deepEqual([...applied], ['m1'], 'replaying the same match is idempotent');
});

test('checkpoint data is local-only and malformed or project-bearing state fails closed', async (context) => {
  assert.throws(() => migrationOptions(['--project=padelx-production']), /refuses/);
  assert.throws(() => parseCheckpoint('{broken'), /invalid or unreadable/);
  assert.throws(() => parseCheckpoint(JSON.stringify({ stage: 'elsewhere' })), /invalid or unreadable/);
  assert.throws(() => parseCheckpoint(JSON.stringify({ stage: 'matches', project: 'other' })),
    /invalid or unreadable/);

  const directory = await mkdtemp(join(tmpdir(), 'phase9-checkpoint-'));
  context.after(() => rm(directory, { recursive: true, force: true }));
  const checkpointPath = join(directory, 'checkpoint.json');
  await writeFile(checkpointPath, JSON.stringify({ usersAfter: 42 }));
  await assert.rejects(loadCheckpoint(checkpointPath), /invalid or unreadable/);
});

test('staging feature gates fail closed independently and require accounting readiness', () => {
  const staging = { mode: 'staging', projectId: 'padelx-staging' };
  assert.throws(() => assertPhase9Enabled(staging, { PADELX_PHASE9_ENABLED: 'false' }));
  assert.throws(() => assertPlayedWithProjectionReady(staging, { PADELX_PLAYED_WITH_PROJECTION_ENABLED: 'false' }));
  assert.throws(() => assertContributionAccountingReady(staging, { PADELX_RATING_CONTRIBUTIONS_READY: 'false' }));
  assert.doesNotThrow(() => assertPhase9Enabled(staging, { PADELX_PHASE9_ENABLED: 'true' }));
  assert.doesNotThrow(() => assertPlayedWithProjectionReady(staging, { PADELX_PLAYED_WITH_PROJECTION_ENABLED: 'true' }));
  assert.doesNotThrow(() => assertContributionAccountingReady(staging, { PADELX_RATING_CONTRIBUTIONS_READY: 'true' }));
});
