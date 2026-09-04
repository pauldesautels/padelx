import { test } from 'node:test';
import assert from 'node:assert/strict';
import { deletionRequestUid } from '../functions/account_deletion.js';
const now = new Date(1000000);
const request = { auth: { uid: 'alice', token: { auth_time: 990, email_verified: false } }, data: {} };
test('admission uses recent authenticated UID, allows unverified users, and accepts empty payload only', () => {
  assert.equal(deletionRequestUid(request, now), 'alice');
  assert.equal(deletionRequestUid({ ...request, data: null }, now), 'alice');
  assert.throws(() => deletionRequestUid({ data: {} }, now), { code: 'unauthenticated' });
  assert.throws(() => deletionRequestUid({ ...request, auth: { uid: 'alice', token: { auth_time: 699 } } }, now), { code: 'failed-precondition' });
  for (const data of [{ uid: 'victim' }, { projectId: 'forged' }, [], 'alice', 1]) {
    assert.throws(() => deletionRequestUid({ ...request, data }, now), { code: 'invalid-argument' });
  }
});
