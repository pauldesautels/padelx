import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
const projectId = 'demo-padelx-phase8';
const app = initializeApp({ projectId }, 'eligibility-callable-tests');
const db = getFirestore(app);
const base = `http://127.0.0.1:5001/${projectId}/us-central1`;

after(() => deleteApp(app));

async function call(name, data, token) {
  const response = await fetch(`${base}/${name}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  return response.json();
}

test('deployed-style eligibility callables gate and record an unverified account', async () => {
  assert.equal((await call('getAgeEligibility', {})).error.status, 'UNAUTHENTICATED');
  const signup = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`,
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-goog-user-project': projectId,
      },
      body: JSON.stringify({
        email: `eligibility-${Date.now()}@example.com`,
        password: 'test-password-123',
        returnSecureToken: true,
      }),
    },
  ).then((response) => response.json());
  assert.ok(signup.idToken, JSON.stringify(signup));

  assert.deepEqual(
    await call('getAgeEligibility', {}, signup.idToken),
    { result: { eligible: false } },
  );
  assert.equal(
    (await call('recordAgeEligibility', {
      confirmed: false,
      version: '18-plus-v1',
      requestId: 'request_123456789',
    }, signup.idToken)).error.status,
    'INVALID_ARGUMENT',
  );
  const payload = {
    confirmed: true,
    version: '18-plus-v1',
    requestId: 'request_123456789',
  };
  assert.deepEqual(await call('recordAgeEligibility', payload, signup.idToken), {
    result: { recorded: true, version: '18-plus-v1' },
  });
  assert.deepEqual(await call('recordAgeEligibility', payload, signup.idToken), {
    result: { recorded: true, version: '18-plus-v1' },
  });
  assert.deepEqual(await call('getAgeEligibility', {}, signup.idToken), {
    result: { eligible: true, version: '18-plus-v1' },
  });

  const record = (await db.doc(`accountEligibility/${signup.localId}`).get()).data();
  assert.equal(record.uid, signup.localId);
  assert.equal(record.age18Confirmed, true);
  assert.equal(record.requestId, undefined);
  assert.ok(Number.isFinite(record.confirmedAt.toMillis()));
});
