import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { deletionStateFor } from '../functions/account_state.js';
import { acceptAccountDeletion, admitAccountDeletion, lockDeletionAuth, dispatchDeletionOutbox } from '../functions/account_deletion.js';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
// Isolate deterministic injected failures from the deployed-style trigger.
const projectId = 'demo-padelx-admission';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'admission-tests');
const db = getFirestore(app);
const auth = getAuth(app);
const now = new Date();
const request = (uid) => ({ auth: { uid, token: { auth_time: Math.floor(now.getTime() / 1000), email_verified: false } }, data: {} });
const read = async (path) => (await db.doc(path).get()).data();
const refs = (uid) => ['accountDeletionBarriers', 'accountDeletionJobs', 'accountDeletionOutbox'].map((name) => `${name}/${uid}`);
after(() => deleteApp(app));

test('admission rejects unauthenticated, stale and forged payloads without writes', async () => {
  await assert.rejects(acceptAccountDeletion(db, { data: {} }, now), { code: 'unauthenticated' });
  await assert.rejects(acceptAccountDeletion(db, { ...request('denied'), auth: { uid: 'denied', token: { auth_time: 1 } } }, now), { code: 'failed-precondition' });
  for (const data of [{ uid: 'victim' }, { projectId: 'forged' }]) {
    await assert.rejects(acceptAccountDeletion(db, { ...request('denied'), data }, now), { code: 'invalid-argument' });
  }
  for (const path of refs('denied')) assert.equal(await read(path), undefined);
});

test('concurrent admission atomically removes profiles and preserves one cutoff and outbox', async () => {
  const uid = 'accepted';
  await db.doc(`users/${uid}`).set({ email: 'private' });
  await db.doc(`publicProfiles/${uid}`).set({ displayName: 'Private' });
  const receipts = await Promise.all([
    acceptAccountDeletion(db, request(uid), now),
    acceptAccountDeletion(db, request(uid), new Date(now.getTime() + 1000)),
  ]);
  receipts.forEach((receipt) => assert.deepEqual(receipt, { status: 'accepted' }));
  const records = await Promise.all(refs(uid).map(read));
  assert.ok(records.every((d) => d.uid === uid));
  assert.ok(records.every((d) => d.deletionRequestedAt.toMillis() === records[0].deletionRequestedAt.toMillis()));
  await acceptAccountDeletion(db, request(uid), new Date(now.getTime() + 2000));
  assert.equal((await read(`accountDeletionJobs/${uid}`)).deletionRequestedAt.toMillis(), records[0].deletionRequestedAt.toMillis());
  assert.equal(await read(`users/${uid}`), undefined);
  assert.equal(await read(`publicProfiles/${uid}`), undefined);
});

test('transaction abort leaves both profiles intact and no partial acceptance', async () => {
  const uid = 'aborted';
  await db.doc(`users/${uid}`).set({ email: 'private' });
  await db.doc(`publicProfiles/${uid}`).set({ displayName: 'Private' });
  const failingDb = {
    projectId: db.projectId, collection: db.collection.bind(db),
    runTransaction: (callback) => db.runTransaction(async (tx) => {
      await callback(tx);
      throw new Error('injected-before-commit');
    }),
  };
  await assert.rejects(acceptAccountDeletion(failingDb, request(uid), now), /injected-before-commit/);
  for (const path of refs(uid)) assert.equal(await read(path), undefined);
  assert.ok(await read(`users/${uid}`)); assert.ok(await read(`publicProfiles/${uid}`));
});

test('durable acceptance precedes Auth; lockdown disables, revokes and never deletes', async () => {
  const uid = 'auth-lock'; await auth.createUser({ uid, emailVerified: false });
  let disableCalls = 0; let revokeCalls = 0;
  const adapter = {
    updateUser: async (...args) => {
      disableCalls++;
      for (const path of refs(uid)) assert.ok(await read(path));
      return auth.updateUser(...args);
    },
    revokeRefreshTokens: async (...args) => { revokeCalls++; return auth.revokeRefreshTokens(...args); },
    deleteUser: () => assert.fail('permanent Auth deletion is prohibited'),
  };
  assert.deepEqual(await admitAccountDeletion(db, adapter, request(uid), now), { status: 'accepted' });
  await admitAccountDeletion(db, adapter, request(uid), now);
  assert.equal(disableCalls, 1); assert.equal(revokeCalls, 1);
  assert.equal((await auth.getUser(uid)).disabled, true);
  const job = await read(`accountDeletionJobs/${uid}`);
  assert.ok(job.authDisabledAt); assert.ok(job.authRevokedAt);
  assert.equal(job.status, 'pending'); assert.equal(job.phase, 'accepted');
  assert.equal((await read(`accountDeletionOutbox/${uid}`)).status, 'ready_for_cleanup');
});

test('partial revoke failure remains durable and resumes without disabling twice', async () => {
  const uid = 'auth-retry'; await auth.createUser({ uid, disabled: true });
  let disables = 0; let revokes = 0;
  const adapter = {
    updateUser: async (...args) => { disables++; return auth.updateUser(...args); },
    revokeRefreshTokens: async (...args) => {
      if (++revokes === 1) throw new Error('transient');
      return auth.revokeRefreshTokens(...args);
    },
  };
  await admitAccountDeletion(db, adapter, request(uid), now);
  assert.equal((await read(`accountDeletionJobs/${uid}`)).status, 'retry_wait');
  assert.equal((await read(`accountDeletionOutbox/${uid}`)).status, 'auth_pending');
  await lockDeletionAuth(db, adapter, uid, now);
  assert.equal(disables, 1); assert.equal(revokes, 2);
  assert.equal((await read(`accountDeletionOutbox/${uid}`)).status, 'ready_for_cleanup');
});

test('missing Auth user is safe and crash after Auth progress still repairs outbox', async () => {
  const uid = 'missing-auth'; await acceptAccountDeletion(db, request(uid), now);
  await lockDeletionAuth(db, auth, uid, now);
  assert.equal((await read(`accountDeletionJobs/${uid}`)).authMissing, true);
  await db.doc(`accountDeletionOutbox/${uid}`).update({ status: 'auth_pending' });
  await lockDeletionAuth(db, { updateUser: () => assert.fail(), revokeRefreshTokens: () => assert.fail() }, uid, now);
  assert.equal((await read(`accountDeletionOutbox/${uid}`)).status, 'ready_for_cleanup');
});

test('corrupt partial state fails closed; failed adapter never consumes outbox', async () => {
  await db.doc('accountDeletionBarriers/corrupt').set({ uid: 'corrupt' });
  await assert.rejects(acceptAccountDeletion(db, request('corrupt'), now), /requires recovery/);
  const results = await dispatchDeletionOutbox(db, async () => { throw new Error('queue unavailable'); }, new Date(now.getTime() + 100000));
  assert.ok(results.length > 0); assert.ok(results.every((r) => r.status === 'rejected'));
  assert.ok(await read('accountDeletionOutbox/accepted'));
});

test('actual callable emulator enforces auth and returns only accepted status for unverified user', async () => {
  const url = 'http://127.0.0.1:5001/demo-padelx-phase8/us-central1/requestAccountDeletion';
  const call = async (data, token) => {
    const response = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify({ data }) });
    return { status: response.status, body: await response.json() };
  };
  assert.equal((await call({})).body.error.status, 'UNAUTHENTICATED');
  const signup = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`, {
    method: 'POST', headers: { 'content-type': 'application/json', 'x-goog-user-project': 'demo-padelx-phase8' },
    body: JSON.stringify({ email: `admission-${Date.now()}@example.com`, password: 'test-password-123', returnSecureToken: true }),
  }).then((r) => r.json());
  assert.ok(signup.idToken, JSON.stringify(signup));
  assert.equal((await call({ uid: 'victim' }, signup.idToken)).body.error.status, 'INVALID_ARGUMENT');
  const pieces = signup.idToken.split('.');
  const claims = JSON.parse(Buffer.from(pieces[1], 'base64url').toString());
  const stale = [pieces[0], Buffer.from(JSON.stringify({ ...claims, auth_time: 1 })).toString('base64url'), pieces[2]].join('.');
  assert.equal((await call({}, stale)).body.error.status, 'FAILED_PRECONDITION');
  assert.deepEqual((await call({}, signup.idToken)).body, { result: { status: 'accepted' } });
  assert.deepEqual((await call({}, signup.idToken)).body, { result: { status: 'accepted' } });
  const functionApp = initializeApp({ projectId: 'demo-padelx-phase8' }, 'callable-check');
  try {
    const user = await getAuth(functionApp).getUser(signup.localId);
    assert.equal(user.disabled, true);
  } finally { await deleteApp(functionApp); }
});


test('outbox creation trigger independently finishes lockdown after acceptance-only crash', async () => {
  const triggerApp = initializeApp({ projectId: 'demo-padelx-phase8' }, 'trigger-check');
  const triggerDb = getFirestore(triggerApp);
  const triggerAuth = getAuth(triggerApp);
  const uid = `trigger-${Date.now()}`;
  try {
    await triggerAuth.createUser({ uid });
    const cutoff = new Date();
    const state = deletionStateFor(uid, cutoff);
    const batch = triggerDb.batch();
    batch.create(triggerDb.doc(`accountDeletionBarriers/${uid}`), state.barrier);
    batch.create(triggerDb.doc(`accountDeletionJobs/${uid}`), { ...state.job, phase: 'disableAuth', authDisabledAt: null, authRevokedAt: null });
    batch.create(triggerDb.doc(`accountDeletionOutbox/${uid}`), { uid, jobId: uid, schemaVersion: 1, status: 'auth_pending', deletionRequestedAt: cutoff, nextAttemptAt: cutoff });
    await batch.commit();
    const deadline = Date.now() + 15000;
    while (Date.now() < deadline) {
      const outbox = (await triggerDb.doc(`accountDeletionOutbox/${uid}`).get()).data();
      if (outbox.status === 'ready_for_cleanup') {
        assert.equal((await triggerAuth.getUser(uid)).disabled, true);
        const job = (await triggerDb.doc(`accountDeletionJobs/${uid}`).get()).data();
        assert.ok(job.authDisabledAt); assert.ok(job.authRevokedAt);
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    assert.fail('outbox trigger did not complete Auth lockdown');
  } finally { await deleteApp(triggerApp); }
});
