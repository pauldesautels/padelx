import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import {
  AGE_ELIGIBILITY_VERSION,
  getAgeEligibilityOperation,
  recordAgeEligibilityOperation,
} from '../functions/eligibility.js';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
const projectId = 'demo-padelx-eligibility';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'eligibility-tests');
const db = getFirestore(app);
const request = (uid, data = {}) => ({
  auth: { uid, token: { email_verified: false } },
  data,
});
const validData = (requestId = 'request_123456789') => ({
  confirmed: true,
  version: AGE_ELIGIBILITY_VERSION,
  requestId,
});

after(() => deleteApp(app));

test('exported eligibility callables enforce App Check outside emulators', async () => {
  const source = await readFile(new URL('../functions/index.js', import.meta.url), 'utf8');
  assert.match(source, /const accountCallable = \(operation\) => onCall\(\{/);
  assert.match(source, /enforceAppCheck: process\.env\.FUNCTIONS_EMULATOR !== 'true'/);
  assert.match(source, /getAgeEligibility = accountCallable\(getAgeEligibilityOperation\)/);
  assert.match(source, /recordAgeEligibility = accountCallable\(recordAgeEligibilityOperation\)/);
});

test('eligibility operations require Auth and reject malformed assertions', async () => {
  await assert.rejects(getAgeEligibilityOperation(db, { data: {} }), {
    code: 'unauthenticated',
  });
  await assert.rejects(recordAgeEligibilityOperation(db, { data: validData() }), {
    code: 'unauthenticated',
  });
  for (const data of [
    { ...validData(), confirmed: false },
    { ...validData(), version: 'future-version' },
    { ...validData(), requestId: 'short' },
    { ...validData(), uid: 'victim' },
  ]) {
    await assert.rejects(recordAgeEligibilityOperation(db, request('alice', data)), {
      code: 'invalid-argument',
    });
  }
});

test('unverified user records one server-authored idempotent assertion', async () => {
  const now = new Date('2026-09-11T12:00:00Z');
  assert.deepEqual(await getAgeEligibilityOperation(db, request('alice')), {
    eligible: false,
  });
  assert.deepEqual(
    await recordAgeEligibilityOperation(db, request('alice', validData()), now),
    { recorded: true, version: AGE_ELIGIBILITY_VERSION },
  );
  const first = (await db.doc('accountEligibility/alice').get()).data();
  assert.equal(first.uid, 'alice');
  assert.equal(first.age18Confirmed, true);
  assert.equal(first.ageEligibilityVersion, AGE_ELIGIBILITY_VERSION);
  assert.equal(first.schemaVersion, 1);
  assert.equal(first.confirmedAt.toMillis(), now.getTime());
  assert.equal(first.requestId, undefined);

  await recordAgeEligibilityOperation(
    db,
    request('alice', validData('different_request_12345')),
    new Date(now.getTime() + 60_000),
  );
  const second = (await db.doc('accountEligibility/alice').get()).data();
  assert.equal(second.confirmedAt.toMillis(), now.getTime());
  assert.deepEqual(await getAgeEligibilityOperation(db, request('alice')), {
    eligible: true,
    version: AGE_ELIGIBILITY_VERSION,
  });
});

test('malformed record gates user and can be replaced by a valid assertion', async () => {
  await db.doc('accountEligibility/malformed').set({
    uid: 'malformed',
    age18Confirmed: false,
    ageEligibilityVersion: AGE_ELIGIBILITY_VERSION,
    confirmedAt: new Date(),
    schemaVersion: 1,
  });
  assert.deepEqual(await getAgeEligibilityOperation(db, request('malformed')), {
    eligible: false,
  });
  await recordAgeEligibilityOperation(
    db,
    request('malformed', validData('repair_request_1234')),
  );
  assert.equal(
    (await db.doc('accountEligibility/malformed').get()).data().age18Confirmed,
    true,
  );
});

test('deletion barrier blocks lookup and recording', async () => {
  await db.doc('accountDeletionBarriers/deleting').set({ status: 'deleting' });
  await assert.rejects(getAgeEligibilityOperation(db, request('deleting')), {
    code: 'permission-denied',
  });
  await assert.rejects(
    recordAgeEligibilityOperation(db, request('deleting', validData())),
    { code: 'permission-denied' },
  );
});
