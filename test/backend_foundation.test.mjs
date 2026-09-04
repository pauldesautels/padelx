import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateBackendEnvironment, backendEnvironment, assertContributionAccountingReady } from '../functions/backend_environment.js';
import { deletionStateFor, requireRecentAuthentication, requireSignedIn } from '../functions/account_state.js';
import { ratingIdentity, ratingAggregateAfterDelta } from '../functions/rating_contributions.js';

const demo = { projectId: 'demo-padelx-phase8', firestoreHost: '127.0.0.1:8080', authHost: '127.0.0.1:9099' };
test('backend project selection fails closed before accessing services', () => {
  assert.equal(validateBackendEnvironment(demo).mode, 'emulator');
  const staging = validateBackendEnvironment({ projectId: 'padelx-staging' });
  assert.equal(staging.mode, 'staging');
  for (const input of [{ projectId: 'padelx-f168f' }, { ...demo, projectId: 'padelx-f168f' },
    { projectId: 'unknown' }, {}, { projectId: demo.projectId },
    { ...demo, authHost: 'remote.example:9099' }, { ...demo, projectId: 'padelx-staging' }]) {
    assert.throws(() => validateBackendEnvironment(input));
  }
  assert.throws(() => backendEnvironment({ GCLOUD_PROJECT: 'padelx-staging', GOOGLE_CLOUD_PROJECT: 'padelx-f168f' }));
  assert.throws(() => backendEnvironment({ FIREBASE_CONFIG: '{bad' }));
  assert.throws(() => assertContributionAccountingReady(staging, {}));
  assert.doesNotThrow(() => assertContributionAccountingReady(staging, { PADELX_RATING_CONTRIBUTIONS_READY: 'true' }));
});

test('recent auth uses only signed auth_time and authenticated UID', () => {
  const request = (authTime) => ({ auth: { uid: 'alice', token: { auth_time: authTime, iat: 1000 } }, data: { uid: 'victim' } });
  assert.equal(requireRecentAuthentication(request(900), { nowSeconds: 1000 }), 'alice');
  assert.equal(requireRecentAuthentication(request(700), { nowSeconds: 1000 }), 'alice');
  for (const value of [699, undefined, null, '900', NaN, Infinity, -1, 0, 900.5, 1001]) {
    assert.throws(() => requireRecentAuthentication(request(value), { nowSeconds: 1000 }), /Recent authentication/);
  }
  assert.throws(() => requireSignedIn({ data: { uid: 'alice' } }), /Authentication required/);
});

test('deletion state records one fixed cutoff and deterministic UID identity', () => {
  const cutoff = new Date('2026-09-03T12:00:00Z');
  const result = deletionStateFor('alice', cutoff);
  assert.equal(result.barrier.uid, result.job.uid);
  assert.equal(result.barrier.schemaVersion, 1);
  assert.equal(result.barrier.deletionRequestedAt, cutoff);
  assert.equal(result.job.deletionRequestedAt, cutoff);
  assert.equal(result.job.phase, 'accepted');
  assert.equal(result.job.status, 'pending');
  assert.equal(result.job.checkpoint, null);
  assert.throws(() => deletionStateFor('alice', new Date('invalid')));
});

test('full rating path determines a stable distinct contribution key', () => {
  const path = 'matches/m/ratingRaters/a/ratings/b';
  assert.equal(ratingIdentity(path).contributionId, ratingIdentity(path).contributionId);
  assert.notEqual(ratingIdentity(path).contributionId, ratingIdentity('matches/n/ratingRaters/a/ratings/b').contributionId);
  assert.throws(() => ratingIdentity('ratings/b'));
});

test('aggregate deltas preserve other contributions and reject corrupt baselines', () => {
  assert.deepEqual(ratingAggregateAfterDelta({ ratingCount: 2, ratingSum: 8 }, 5, 0), {
    ratingCount: 1, ratingSum: 3, ratingAverage: 3,
  });
  assert.deepEqual(ratingAggregateAfterDelta({ ratingCount: 1, ratingSum: 3 }, 3, 0), {
    ratingCount: 0, ratingSum: 0, ratingAverage: 0,
  });
  assert.deepEqual(ratingAggregateAfterDelta({ ratingCount: 2, ratingSum: 8 }, 5, 1), {
    ratingCount: 2, ratingSum: 4, ratingAverage: 2,
  });
  assert.throws(() => ratingAggregateAfterDelta({ ratingCount: 0, ratingSum: 0 }, 5, 0), /baseline inconsistent/);
  assert.throws(() => ratingAggregateAfterDelta({ ratingCount: 1, ratingSum: 99 }, 0, 5), /baseline inconsistent/);
  assert.throws(() => ratingAggregateAfterDelta({}, 0, NaN), /Invalid contribution/);
});
