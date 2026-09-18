import test, { after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { deliverNotificationPushOperation, pushCopy, pushRouteData }
  from '../functions/push_delivery.js';
import { pushTokenHash } from '../functions/push_devices.js';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-padelx-push-delivery';
const app = initializeApp({ projectId }, 'push-delivery-tests');
const db = getFirestore(app);
after(() => deleteApp(app));

beforeEach(async () => {
  await db.doc('users/recipient/settings/notifications').delete();
  await db.doc('accountEnforcement/recipient').delete();
  await db.doc('accountDeletionBarriers/recipient').delete();
  for (const collection of ['pushDevices', 'pushDeliveryReceipts', 'users']) {
    const snapshot = await db.collection(collection).get();
    await Promise.all(snapshot.docs.map((document) => document.ref.delete()));
  }
});

const token = (name) => `token-${name}-${'x'.repeat(30)}`;
const notification = (type = 'matchmaking_match_found') => ({
  type,
  recipientUid: 'recipient',
  matchId: 'synthetic-match',
});

function messaging(results) {
  return {
    messages: [],
    async sendEach(messages) {
      this.messages.push(...messages);
      const responses = results ?? messages.map(() => ({ success: true }));
      return { responses, successCount: responses.filter((item) => item.success).length };
    },
  };
}

async function enable() {
  await db.doc('users/recipient').set({ uid: 'recipient', accountState: 'active' });
  await db.doc('users/recipient/settings/notifications').set({ pushEnabled: true });
}

async function device(name, locale = 'en') {
  const value = token(name);
  await db.doc(`pushDevices/${pushTokenHash(value)}`).set({
    uid: 'recipient', token: value, enabled: true, locale,
  });
  return value;
}

test('localized delivery is recipient-bound, generic, and retry-idempotent', async () => {
  await enable();
  await device('english');
  await device('spanish', 'es-MX');
  await device('other-user');
  await db.doc(`pushDevices/${pushTokenHash(token('other-user'))}`).update({ uid: 'other' });
  const gateway = messaging();
  const first = await deliverNotificationPushOperation(
    db, gateway, 'notification-one', notification(), new Date('2030-01-01T00:00:00Z'),
  );
  const retry = await deliverNotificationPushOperation(
    db, gateway, 'notification-one', notification(), new Date('2030-01-01T00:01:00Z'),
  );
  assert.deepEqual(first, { status: 'complete', sent: 2 });
  assert.deepEqual(retry, { status: 'duplicate', sent: 0 });
  assert.equal(gateway.messages.length, 2);
  assert.deepEqual(gateway.messages.map((item) => item.notification.title).sort(),
    ['Match found', 'Partido encontrado']);
  assert.ok(gateway.messages.every((item) => item.data.route === 'quick_match'));
  assert.ok(gateway.messages.every((item) => !JSON.stringify(item).includes('private')));
});

test('opt-out and unsupported notification types never send', async () => {
  await device('disabled');
  const gateway = messaging();
  assert.equal((await deliverNotificationPushOperation(
    db, gateway, 'disabled', notification(),
  )).sent, 0);
  await enable();
  assert.equal((await deliverNotificationPushOperation(
    db, gateway, 'ignored', notification('direct_message'),
  )).status, 'ignored');
  assert.equal(gateway.messages.length, 0);
});

test('match update category opt-out suppresses matchmaking delivery', async () => {
  await enable();
  await db.doc('users/recipient/settings/notifications').update({ matchUpdates: false });
  await device('category-disabled');
  const gateway = messaging();
  assert.equal((await deliverNotificationPushOperation(
    db, gateway, 'category-disabled', notification(),
  )).sent, 0);
  assert.equal(gateway.messages.length, 0);
});

test('deleted and effectively enforced recipients never receive delivery', async () => {
  await enable();
  await device('restricted');
  const gateway = messaging();
  await db.doc('accountEnforcement/recipient').set({
    schemaVersion: 1, uid: 'recipient', status: 'banned',
    reasonCode: 'other_policy_violation',
  });
  assert.equal((await deliverNotificationPushOperation(
    db, gateway, 'enforced', notification(),
  )).sent, 0);
  await db.doc('accountEnforcement/recipient').delete();
  await db.doc('accountDeletionBarriers/recipient').set({ uid: 'recipient' });
  assert.equal((await deliverNotificationPushOperation(
    db, gateway, 'deleting', notification(),
  )).sent, 0);
  assert.equal(gateway.messages.length, 0);
});

test('invalid provider token is removed without persisting token material', async () => {
  await enable();
  const value = await device('invalid');
  const gateway = messaging([{ success: false, error: {
    code: 'messaging/registration-token-not-registered',
  } }]);
  await deliverNotificationPushOperation(db, gateway, 'invalid-token', notification());
  assert.equal((await db.doc(`pushDevices/${pushTokenHash(value)}`).get()).exists, false);
  const receipt = (await db.doc('pushDeliveryReceipts/invalid-token').get()).data();
  assert.deepEqual({ status: receipt.status, sentCount: receipt.sentCount,
    failedCount: receipt.failedCount }, { status: 'complete', sentCount: 0, failedCount: 1 });
  assert.equal(JSON.stringify(receipt).includes(value), false);
});

test('confirmed match route requires and retains only canonical match identifier', () => {
  assert.deepEqual(pushRouteData(notification('matchmaking_match_confirmed')), {
    type: 'matchmaking_match_confirmed', route: 'match',
    matchId: 'synthetic-match',
  });
  assert.equal(pushCopy('matchmaking_match_found', 'unsupported')[0], 'Match found');
});
