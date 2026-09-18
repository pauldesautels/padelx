import { after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { COMMUNITY_VERSION, LEGAL_SCHEMA_VERSION, PRIVACY_VERSION, TERMS_VERSION,
  getLegalAcceptanceOperation, recordLegalAcceptanceOperation } from '../functions/legal_acceptance.js';

const projectId = 'demo-padelx-legal';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'legal-tests');
const db = getFirestore(app);
const request = (uid, data = {}) => ({ auth: { uid, token: { email_verified: false } }, data });
const payload = (requestId = 'legal_request_123456') => ({ acknowledged: true,
  termsVersion: TERMS_VERSION, privacyVersion: PRIVACY_VERSION,
  communityVersion: COMMUNITY_VERSION, requestId });

beforeEach(async () => {
  for (const collection of await db.listCollections()) {
    for (const ref of await collection.listDocuments()) await db.recursiveDelete(ref);
  }
});
after(() => deleteApp(app));

test('legal acceptance is exact, server-timestamped, and idempotent', async () => {
  const now = new Date('2026-09-14T12:00:00Z');
  assert.deepEqual(await getLegalAcceptanceOperation(db, request('alice')), { accepted: false });
  const receipt = await recordLegalAcceptanceOperation(db, request('alice', payload()), now);
  assert.equal(receipt.recorded, true);
  const stored = (await db.doc('accountLegalAcceptance/alice').get()).data();
  assert.deepEqual({ ...stored, acceptedAt: stored.acceptedAt.toDate() }, {
    uid: 'alice', termsVersion: TERMS_VERSION, privacyVersion: PRIVACY_VERSION,
    communityVersion: COMMUNITY_VERSION, acceptedAt: now, schemaVersion: LEGAL_SCHEMA_VERSION,
  });
  await recordLegalAcceptanceOperation(db, request('alice', payload('legal_request_654321')), new Date());
  assert.equal((await db.doc('accountLegalAcceptance/alice').get()).data().acceptedAt.toMillis(), now.getTime());
  assert.equal((await getLegalAcceptanceOperation(db, request('alice'))).accepted, true);
});
test('v1 and mixed receipts do not satisfy the exact v2 requirement', async () => {
  const acceptedAt = new Date('2026-09-14T12:00:00Z');
  await db.doc('accountLegalAcceptance/legacy').set({
    uid: 'legacy', schemaVersion: 1, termsVersion: 'terms-beta-v1',
    privacyVersion: 'privacy-beta-v1', communityVersion: 'community-beta-v1',
    acceptedAt,
  });
  assert.deepEqual(await getLegalAcceptanceOperation(db, request('legacy')), { accepted: false });

  await db.doc('accountLegalAcceptance/mixed').set({
    uid: 'mixed', schemaVersion: 1, termsVersion: TERMS_VERSION,
    privacyVersion: 'privacy-beta-v1', communityVersion: COMMUNITY_VERSION,
    acceptedAt,
  });
  assert.deepEqual(await getLegalAcceptanceOperation(db, request('mixed')), { accepted: false });
});

test('exact v2 receipt satisfies the gate and schema remains one', async () => {
  assert.equal(LEGAL_SCHEMA_VERSION, 1);
  const acceptedAt = new Date('2026-09-18T12:00:00Z');
  await db.doc('accountLegalAcceptance/current').set({
    uid: 'current', schemaVersion: LEGAL_SCHEMA_VERSION,
    termsVersion: TERMS_VERSION, privacyVersion: PRIVACY_VERSION,
    communityVersion: COMMUNITY_VERSION, acceptedAt,
  });
  const state = await getLegalAcceptanceOperation(db, request('current'));
  assert.deepEqual(state, {
    accepted: true, termsVersion: TERMS_VERSION, privacyVersion: PRIVACY_VERSION,
    communityVersion: COMMUNITY_VERSION,
  });
});
test('legal acceptance rejects missing auth, unknown versions, extra fields, and deletion', async () => {
  await assert.rejects(recordLegalAcceptanceOperation(db, { data: payload() }), { code: 'unauthenticated' });
  for (const invalid of [{ ...payload(), termsVersion: 'future' },
    { ...payload(), acknowledged: false }, { ...payload(), uid: 'victim' }]) {
    await assert.rejects(recordLegalAcceptanceOperation(db, request('alice', invalid)), { code: 'invalid-argument' });
  }
  await db.doc('accountDeletionBarriers/alice').set({ status: 'deleting' });
  await assert.rejects(recordLegalAcceptanceOperation(db, request('alice', payload())), { code: 'permission-denied' });
});
