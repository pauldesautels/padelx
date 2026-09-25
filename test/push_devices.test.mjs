import test, { after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import {
  pushTokenHash,
  registerPushDeviceOperation,
  unregisterPushDeviceOperation,
  validatePushDeviceIdentity,
} from '../functions/push_devices.js';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-padelx-push-devices';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'push-device-tests');
const db = getFirestore(app);
after(() => deleteApp(app));
beforeEach(async () => {
  const docs = await db.collection('pushDevices').get();
  await Promise.all(docs.docs.map((doc) => doc.ref.delete()));
  const barriers = await db.collection('accountDeletionBarriers').get();
  await Promise.all(barriers.docs.map((doc) => doc.ref.delete()));
});

const token = (suffix) => `fcm-token-${suffix}-${'x'.repeat(32)}`;
const request = (uid, value, overrides = {}) => ({
  auth: { uid, token: { email_verified: true } },
  data: {
    token: value,
    platform: 'ios',
    firebaseProjectId: projectId,
    firebaseAppId: '1:708585002488:ios:test-app',
    bundleId: 'com.padelx.app.devicetest',
    ...overrides,
  },
  app: { appId: '1:708585002488:ios:test-app' },
  rawRequest: { pushNow: new Date('2026-09-10T12:00:00Z') },
});

const androidRequest = (uid, value, overrides = {}) => {
  const result = request(uid, value, {
    platform: 'android',
    firebaseAppId: '1:708585002488:android:test-app',
    bundleId: undefined,
    packageName: 'com.example.padelx',
    ...overrides,
  });
  result.app.appId = result.data.firebaseAppId;
  return result;
};

test('valid registration is idempotent and never trusts a supplied UID', async () => {
  const value = token('same');
  await registerPushDeviceOperation(db, request('alice', value, { uid: 'mallory' }));
  await registerPushDeviceOperation(db, request('alice', value));
  const snapshot = await db.doc(`pushDevices/${pushTokenHash(value)}`).get();
  assert.equal(snapshot.data().uid, 'alice');
  assert.equal(snapshot.data().token, value);
  assert.equal(snapshot.data().platform, 'ios');
  assert.equal(snapshot.data().locale, 'en');
  assert.equal((await db.collection('pushDevices').get()).size, 1);
});

test('registration stores only a supported delivery locale', async () => {
  const spanish = token('spanish');
  await registerPushDeviceOperation(db, request('alice', spanish, { locale: 'es-MX' }));
  assert.equal((await db.doc(`pushDevices/${pushTokenHash(spanish)}`).get()).data().locale,
    'es-MX');
  const fallback = token('fallback');
  await registerPushDeviceOperation(db, request('alice', fallback, { locale: 'fr' }));
  assert.equal((await db.doc(`pushDevices/${pushTokenHash(fallback)}`).get()).data().locale,
    'en');
});

test('multiple tokens register independently and the same token transfers accounts', async () => {
  const first = token('first');
  const second = token('second');
  await registerPushDeviceOperation(db, request('alice', first));
  await registerPushDeviceOperation(db, request('alice', second));
  assert.equal((await db.collection('pushDevices').where('uid', '==', 'alice').get()).size, 2);
  await registerPushDeviceOperation(db, request('bob', first));
  assert.equal((await db.doc(`pushDevices/${pushTokenHash(first)}`).get()).data().uid, 'bob');
  assert.equal((await db.collection('pushDevices').where('uid', '==', 'alice').get()).size, 1);
});

test('iOS and Android devices share the registry without identity overlap', async () => {
  const ios = token('ios');
  const android = token('android');
  await registerPushDeviceOperation(db, request('alice', ios));
  await registerPushDeviceOperation(db, androidRequest('alice', android));
  const documents = await db.collection('pushDevices').where('uid', '==', 'alice').get();
  assert.equal(documents.size, 2);
  assert.equal((await db.doc(`pushDevices/${pushTokenHash(ios)}`).get()).data().bundleId,
    'com.padelx.app.devicetest');
  const androidData = (await db.doc(`pushDevices/${pushTokenHash(android)}`).get()).data();
  assert.equal(androidData.platform, 'android');
  assert.equal(androidData.packageName, 'com.example.padelx');
  assert.equal('bundleId' in androidData, false);
});

test('unregister is idempotent and clears stale ownership after account switch', async () => {
  const value = token('remove');
  await registerPushDeviceOperation(db, request('alice', value));
  await unregisterPushDeviceOperation(db, request('bob', value));
  await unregisterPushDeviceOperation(db, request('bob', value));
  assert.equal((await db.doc(`pushDevices/${pushTokenHash(value)}`).get()).exists, false);
});

test('invalid tokens, platform, project, bundle, and attested app are rejected', async () => {
  await assert.rejects(registerPushDeviceOperation(db, request('alice', 'short')));
  await assert.rejects(registerPushDeviceOperation(db, request('alice', 'x'.repeat(4097))));
  await assert.rejects(registerPushDeviceOperation(db, request('alice', token('platform'), { platform: 'android' })));
  await assert.rejects(registerPushDeviceOperation(db, request('alice', token('project'), { firebaseProjectId: 'padelx-f168f' })));
  await assert.rejects(registerPushDeviceOperation(db, request('alice', token('bundle'), { bundleId: 'com.example.padelx' })));
  const mismatched = request('alice', token('app'));
  mismatched.app.appId = 'different-app';
  await assert.rejects(registerPushDeviceOperation(db, mismatched));
  await assert.rejects(registerPushDeviceOperation(db,
    androidRequest('alice', token('android-package'), { packageName: 'com.example.other' })));
  assert.throws(() => validatePushDeviceIdentity(
    androidRequest('alice', token('android-app'), {
      firebaseAppId: '1:425226080221:android:prod',
    }),
    { projectId: 'padelx-staging', mode: 'staging' },
  ));
});

test('authentication, verification, and deletion barrier are enforced', async () => {
  const value = token('auth');
  await assert.rejects(registerPushDeviceOperation(db, { ...request('alice', value), auth: null }));
  await assert.rejects(registerPushDeviceOperation(db, {
    ...request('alice', value), auth: { uid: 'alice', token: {} },
  }));
  await db.doc('accountDeletionBarriers/alice').set({ status: 'deleting' });
  await assert.rejects(registerPushDeviceOperation(db, request('alice', value)));
});

test('production push identity accepts only permanent production applications', () => {
  const productionEnvironment = { projectId: 'padelx-f168f', mode: 'production' };
  const ios = request('alice', token('production-ios'), {
    firebaseProjectId: 'padelx-f168f',
    firebaseAppId: '1:425226080221:ios:production-app',
    bundleId: 'com.padelx.app',
  });
  ios.app.appId = ios.data.firebaseAppId;
  assert.equal(validatePushDeviceIdentity(ios, productionEnvironment).bundleId,
    'com.padelx.app');

  const android = androidRequest('alice', token('production-android'), {
    firebaseProjectId: 'padelx-f168f',
    firebaseAppId: '1:425226080221:android:production-app',
    packageName: 'com.pabloware.padelx',
  });
  android.app.appId = android.data.firebaseAppId;
  assert.equal(validatePushDeviceIdentity(android, productionEnvironment).packageName,
    'com.pabloware.padelx');

  ios.data.bundleId = 'com.padelx.app.devicetest';
  assert.throws(() => validatePushDeviceIdentity(ios, productionEnvironment));
  android.data.packageName = 'com.example.padelx';
  assert.throws(() => validatePushDeviceIdentity(android, productionEnvironment));
  android.data.packageName = 'com.padelx.app';
  assert.throws(() => validatePushDeviceIdentity(android, productionEnvironment));
});

test('callable exports retain the shared App Check protected wrapper', async () => {
  const source = await import('node:fs/promises').then(({ readFile }) =>
    readFile(new URL('../functions/index.js', import.meta.url), 'utf8'));
  assert.match(source, /registerPushDevice = socialCallable\(registerPushDeviceOperation\)/);
  assert.match(source, /unregisterPushDevice = socialCallable\(unregisterPushDeviceOperation\)/);
  assert.match(source, /enforceAppCheck: process\.env\.FUNCTIONS_EMULATOR !== 'true'/);
});
