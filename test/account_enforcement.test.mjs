import { after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import {
  ENFORCEMENT_REASONS,
  applyAccountEnforcement,
  getAccountAccessStateOperation,
  getEffectiveAccountEnforcement,
  revokeAccountEnforcement,
} from '../functions/account_enforcement.js';
import { requireActiveAccount } from '../functions/account_state.js';
import { buildEnforcementInput } from '../tool/safety_admin/policy.mjs';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Firestore emulator is required');
const projectId = 'demo-padelx-enforcement';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'enforcement-tests');
const db = getFirestore(app);
after(() => deleteApp(app));
beforeEach(async () => {
  for (const name of ['users', 'reports', 'accountEnforcement', 'moderationActions']) {
    const docs = await db.collection(name).listDocuments();
    await Promise.all(docs.map((document) => document.delete()));
  }
});

const now = new Date('2030-01-01T12:00:00Z');
const later = new Date('2030-01-02T12:00:00Z');
const input = (overrides = {}) => ({
  actorUid: 'trusted-actor',
  targetUid: 'target-user',
  requestId: 'request_1234567890',
  status: 'suspended',
  reasonCode: 'harassment_abuse',
  sourceReportIds: [],
  expiresAt: later,
  ...overrides,
});
const request = (uid = 'target-user') => ({ auth: { uid, token: { email_verified: true } } });

function auth({ fail = false } = {}) {
  return {
    revoked: 0,
    disabled: 0,
    async revokeRefreshTokens() {
      this.revoked++;
      if (fail) throw new Error('safe test failure');
    },
    async updateUser() { this.disabled++; },
  };
}

test('effective state uses an injected authoritative clock and fails closed', () => {
  const suspended = { schemaVersion: 1, uid: 'target-user', status: 'suspended',
    reasonCode: 'harassment_abuse', expiresAt: later };
  assert.equal(getEffectiveAccountEnforcement(suspended, now)?.status, 'suspended');
  assert.equal(getEffectiveAccountEnforcement(suspended, later), null);
  assert.equal(getEffectiveAccountEnforcement(suspended, new Date(later.getTime() + 1)), null);
  assert.equal(getEffectiveAccountEnforcement({ ...suspended, expiresAt: 'bad' }, now)?.malformed, true);
  assert.equal(getEffectiveAccountEnforcement({ ...suspended, status: 'banned', expiresAt: undefined }, now)?.malformed, true);
  assert.equal(getEffectiveAccountEnforcement({ ...suspended, status: 'banned' }, now)?.status, 'banned');
});

test('apply validates policy, reports, target, and never disables Auth', async () => {
  await db.doc('users/target-user').set({ uid: 'target-user' });
  await db.doc('reports/report-one').set({ status: 'open' });
  const identity = auth();
  for (const invalid of [
    input({ expiresAt: now }),
    input({ status: 'banned' }),
    input({ reasonCode: 'arbitrary' }),
    input({ sourceReportIds: ['missing-report'] }),
    input({ sourceReportIds: Array(21).fill(0).map((_, index) => `report-${index}`) }),
    input({ sourceReportIds: ['report-one', 'report-one'] }),
  ]) await assert.rejects(applyAccountEnforcement(db, identity, invalid, now));
  assert.deepEqual(ENFORCEMENT_REASONS.includes('other_policy_violation'), true);
  const result = await applyAccountEnforcement(db, identity,
    input({ sourceReportIds: ['report-one'] }), now);
  assert.equal(result.changed, true);
  assert.equal(typeof result.moderationActionId, 'string');
  assert.equal(identity.revoked, 1);
  assert.equal(identity.disabled, 0);
  assert.equal((await db.doc('reports/report-one').get()).data().status, 'open');
  const actions = await db.collection('moderationActions').get();
  assert.equal(actions.size, 1);
  assert.equal(actions.docs[0].data().type, 'suspension_applied');
});

test('CLI singular source report input persists for suspension and ban audits', async () => {
  await db.doc('users/target-user').set({ uid: 'target-user' });
  await db.doc('reports/report-cli-source').set({ status: 'reviewing' });
  const identity = auth();
  const common = { options: { reason: 'threats_unsafe_behavior', minutes: '10',
    'source-report-id': 'report-cli-source' }, actorUid: 'trusted-actor',
  targetUid: 'target-user', now };
  const suspended = buildEnforcementInput({ ...common, command: 'suspend',
    requestId: '123e4567-e89b-42d3-a456-426614174000' });
  assert.deepEqual(suspended.sourceReportIds, ['report-cli-source']);
  await applyAccountEnforcement(db, identity, suspended, now);
  const banned = buildEnforcementInput({ ...common, command: 'ban',
    requestId: '123e4567-e89b-42d3-a456-426614174001' });
  assert.deepEqual(banned.sourceReportIds, ['report-cli-source']);
  await applyAccountEnforcement(db, identity, banned, now);
  const actions = await db.collection('moderationActions').get();
  const applied = actions.docs.map((document) => document.data())
    .filter((action) => ['suspension_applied', 'ban_applied'].includes(action.type));
  assert.equal(applied.length, 2);
  assert.ok(applied.every((action) =>
    JSON.stringify(action.sourceReportIds) === JSON.stringify(['report-cli-source'])));
});

test('apply is idempotent and token failure cannot remove enforcement', async () => {
  await db.doc('users/target-user').set({ uid: 'target-user' });
  const failingAuth = auth({ fail: true });
  const first = await applyAccountEnforcement(db, failingAuth, input(), now);
  const second = await applyAccountEnforcement(db, failingAuth, input(), now);
  assert.equal(first.tokenRevocationPending, true);
  assert.equal(second.idempotent, true);
  assert.equal(failingAuth.revoked, 2);
  assert.equal((await db.doc('accountEnforcement/target-user').get()).exists, true);
  assert.equal((await db.collection('moderationActions').get()).size, 1);
});

test('ban and explicit revoke preserve immutable audit history', async () => {
  await db.doc('users/target-user').set({ uid: 'target-user' });
  await db.doc('reports/report-ban-source').set({ status: 'reviewing' });
  const identity = auth();
  await applyAccountEnforcement(db, identity,
    input({ status: 'banned', expiresAt: undefined,
      sourceReportIds: ['report-ban-source'] }), now);
  const applied = (await db.collection('moderationActions')
    .where('type', '==', 'ban_applied').get()).docs[0].data();
  assert.deepEqual(applied.sourceReportIds, ['report-ban-source']);
  assert.deepEqual((await db.doc('accountEnforcement/target-user').get())
    .data().sourceReportIds, ['report-ban-source']);
  const restricted = await getAccountAccessStateOperation(db, request(), now);
  assert.deepEqual(restricted, {
    restricted: true, status: 'banned', reasonCategory: 'harassment_abuse',
  });
  const revoked = await revokeAccountEnforcement(db, identity, {
    actorUid: 'trusted-actor', targetUid: 'target-user', requestId: 'revoke_1234567890',
  }, later);
  assert.equal(revoked.changed, true);
  assert.equal((await db.doc('accountEnforcement/target-user').get()).exists, false);
  assert.equal((await db.collection('moderationActions').get()).size, 2);
  const retry = await revokeAccountEnforcement(db, identity, {
    actorUid: 'trusted-actor', targetUid: 'target-user', requestId: 'revoke_1234567890',
  }, later);
  assert.equal(retry.idempotent, true);
  assert.equal((await db.collection('moderationActions').get()).size, 2);
});

test('shared callable admission rejects effective enforcement and permits expiry', async () => {
  await db.doc('users/target-user').set({ uid: 'target-user' });
  await db.doc('accountEnforcement/target-user').set({ schemaVersion: 1, uid: 'target-user',
    status: 'suspended', reasonCode: 'harassment_abuse', expiresAt: later });
  await assert.rejects(requireActiveAccount(db, request(), { now }), { code: 'permission-denied' });
  assert.equal(await requireActiveAccount(db, request(), { now: later }), 'target-user');
});

test('exports admit all normal callables through the shared gate with explicit exceptions', async () => {
  const source = await readFile(new URL('../functions/index.js', import.meta.url), 'utf8');
  for (const name of [
    'requestFriend', 'respondToFriendRequest', 'cancelFriendRequest', 'removeFriend',
    'blockPlayer', 'unblockPlayer', 'listBlockedPlayers', 'getRelationshipPolicies',
    'ensureDirectConversation', 'ensureMatchConversation', 'sendMessage', 'listMessages',
    'listConversations', 'markConversationRead', 'createPlayAgainInvitation',
    'dismissPlayAgainInvitation', 'discoverPlayers', 'registerPushDevice',
  ]) assert.match(source, new RegExp(`export const ${name} = socialCallable\\(`));
  for (const name of ['getAgeEligibility', 'recordAgeEligibility', 'submitReport']) {
    assert.match(source, new RegExp(`export const ${name} = accountCallable\\(`));
  }
  assert.match(source, /export const requestAccountDeletion = onCall\(/);
  assert.match(source, /export const unregisterPushDevice = socialCallable\(unregisterPushDeviceOperation\)/);
  assert.match(source, /export const getAccountAccessState = accountCallable\(getAccountAccessStateOperation\)/);
  const pushSource = await readFile(new URL('../functions/push_devices.js', import.meta.url), 'utf8');
  assert.match(pushSource, /unregisterPushDeviceOperation[\s\S]*requireSignedIn\(request\)/);
  const reportSource = await readFile(new URL('../functions/reports.js', import.meta.url), 'utf8');
  assert.doesNotMatch(reportSource, /accountEnforcement|applyAccountEnforcement/);
});
