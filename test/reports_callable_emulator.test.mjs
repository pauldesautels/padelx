import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
const projectId = 'demo-padelx-phase8';
const app = initializeApp({ projectId }, 'report-callable-test');
const db = getFirestore(app);
const auth = getAuth(app);
after(() => deleteApp(app));

async function call(data, token) {
  const response = await fetch(`http://127.0.0.1:5001/${projectId}/us-central1/submitReport`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  return response.json();
}

test('deployed-style submitReport enforces admission and returns private minimal receipt', async () => {
  const email = `reporter-${Date.now()}@example.com`;
  const password = 'test-password-123';
  const signup = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`,
    {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  ).then((response) => response.json());
  assert.ok(signup.idToken, JSON.stringify(signup));
  const data = {
    requestId: 'callable_report_request_1', subjectType: 'player',
    subjectId: 'callable-target', reason: 'other', details: 'context',
  };
  assert.equal((await call(data)).error.status, 'UNAUTHENTICATED');
  assert.equal((await call(data, signup.idToken)).error.status, 'PERMISSION_DENIED');

  await auth.updateUser(signup.localId, { emailVerified: true });
  const signin = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key`,
    {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  ).then((response) => response.json());
  assert.ok(signin.idToken, JSON.stringify(signin));
  const now = new Date();
  await db.doc(`users/${signup.localId}`).set({ uid: signup.localId, active: true });
  await db.doc(`publicProfiles/${signup.localId}`).set({ uid: signup.localId, displayName: 'Reporter' });
  await db.doc(`accountEligibility/${signup.localId}`).set({
    uid: signup.localId, age18Confirmed: true, ageEligibilityVersion: '18-plus-v1',
    confirmedAt: now, schemaVersion: 1,
  });
  await db.doc('users/callable-target').set({ uid: 'callable-target', active: true });
  await db.doc('publicProfiles/callable-target').set({
    uid: 'callable-target', displayName: 'Target', bio: 'Reported context', avatarVersion: 1,
  });

  assert.deepEqual(await call(data, signin.idToken), {
    result: { submitted: true, duplicate: false },
  });
  assert.deepEqual(await call(data, signin.idToken), {
    result: { submitted: true, duplicate: true },
  });
  const stored = (await db.collection('reports').get()).docs.map((doc) => doc.data());
  assert.equal(stored.length, 1);
  assert.deepEqual(stored[0].evidence, {
    displayName: 'Target', bio: 'Reported context', avatarVersion: 1,
  });
});
