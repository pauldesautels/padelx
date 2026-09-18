import { createHash } from 'node:crypto';
import { getEffectiveAccountEnforcement } from './account_enforcement.js';

const PUSHABLE_TYPES = Object.freeze(new Set([
  'matchmaking_partner_invite',
  'matchmaking_match_found',
  'matchmaking_replacement_found',
  'matchmaking_match_confirmed',
]));
const INVALID_TOKEN_CODES = Object.freeze(new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
  'messaging/mismatched-credential',
]));

const COPY = Object.freeze({
  en: Object.freeze({
    matchmaking_partner_invite: ['Partner invitation',
      'A player invited you to search for a Quick Match together.'],
    matchmaking_match_found: ['Match found',
      'Your Quick Match offer is ready. Open PadelX to respond.'],
    matchmaking_replacement_found: ['Match spot found',
      'A match spot is ready. Open PadelX to respond.'],
    matchmaking_match_confirmed: ['Match confirmed',
      'Your match is confirmed. Open PadelX for details.'],
  }),
  'es-MX': Object.freeze({
    matchmaking_partner_invite: ['Invitación de compañero',
      'Un jugador te invitó a buscar un Quick Match juntos.'],
    matchmaking_match_found: ['Partido encontrado',
      'Tu oferta de Quick Match está lista. Abre PadelX para responder.'],
    matchmaking_replacement_found: ['Lugar disponible',
      'Hay un lugar listo para ti. Abre PadelX para responder.'],
    matchmaking_match_confirmed: ['Partido confirmado',
      'Tu partido está confirmado. Abre PadelX para ver los detalles.'],
  }),
});

const digest = (value) => createHash('sha256').update(value, 'utf8').digest('hex');

export function pushCopy(type, locale) {
  const normalized = locale === 'es-MX' ? 'es-MX' : 'en';
  return COPY[normalized][type] ?? null;
}

export function pushRouteData(data) {
  const type = data?.type;
  if (!PUSHABLE_TYPES.has(type)) return null;
  const route = type === 'matchmaking_match_confirmed' && typeof data.matchId === 'string'
    && data.matchId.length > 0 ? 'match' : 'quick_match';
  return {
    type,
    route,
    ...(route === 'match' ? { matchId: data.matchId } : {}),
  };
}

export async function deliverNotificationPushOperation(
  firestore,
  messaging,
  notificationId,
  notification,
  now = new Date(),
) {
  const routeData = pushRouteData(notification);
  const uid = notification?.recipientUid;
  if (!routeData || typeof uid !== 'string' || uid.length === 0) {
    return { status: 'ignored', sent: 0 };
  }
  const receiptRef = firestore.doc(`pushDeliveryReceipts/${notificationId}`);
  const claimed = await firestore.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) return false;
    transaction.create(receiptRef, {
      recipientUid: uid,
      notificationType: notification.type,
      status: 'processing',
      createdAt: now,
      updatedAt: now,
    });
    return true;
  });
  if (!claimed) return { status: 'duplicate', sent: 0 };

  try {
    const [preferences, devices, user, deletionBarrier, enforcement] = await Promise.all([
      firestore.doc(`users/${uid}/settings/notifications`).get(),
      firestore.collection('pushDevices').where('uid', '==', uid).limit(20).get(),
      firestore.doc(`users/${uid}`).get(),
      firestore.doc(`accountDeletionBarriers/${uid}`).get(),
      firestore.doc(`accountEnforcement/${uid}`).get(),
    ]);
    if (!user.exists || deletionBarrier.exists
        || getEffectiveAccountEnforcement(enforcement.data(), now) != null
        || preferences.data()?.pushEnabled !== true
        || preferences.data()?.matchUpdates === false || devices.empty) {
    await receiptRef.set({ status: 'complete', sentCount: 0, updatedAt: now }, { merge: true });
    return { status: 'complete', sent: 0 };
    }

    const messages = devices.docs.flatMap((device) => {
    const value = device.data();
    if (value.enabled !== true || typeof value.token !== 'string') return [];
    const copy = pushCopy(notification.type, value.locale);
    if (!copy) return [];
    const collapseId = digest(notificationId).slice(0, 32);
    return [{
      token: value.token,
      notification: { title: copy[0], body: copy[1] },
      data: routeData,
      android: { collapseKey: collapseId, priority: 'high' },
      apns: {
        headers: { 'apns-collapse-id': collapseId, 'apns-priority': '10' },
        payload: { aps: { sound: 'default' } },
      },
    }];
    });
    if (messages.length === 0) {
    await receiptRef.set({ status: 'complete', sentCount: 0, updatedAt: now }, { merge: true });
    return { status: 'complete', sent: 0 };
    }

    const response = await messaging.sendEach(messages);
    const invalidTokens = [];
    response.responses.forEach((result, index) => {
    if (!result.success && INVALID_TOKEN_CODES.has(result.error?.code)) {
      invalidTokens.push(messages[index].token);
    }
    });
    if (invalidTokens.length > 0) {
    const invalidHashes = new Set(invalidTokens.map((token) => digest(token)));
    const batch = firestore.batch();
    for (const device of devices.docs) {
      if (invalidHashes.has(device.id)) batch.delete(device.ref);
    }
    await batch.commit();
    }
    const sent = response.successCount ?? response.responses.filter((item) => item.success).length;
    await receiptRef.set({ status: 'complete', sentCount: sent,
      failedCount: messages.length - sent, updatedAt: now }, { merge: true });
    return { status: 'complete', sent };
  } catch (error) {
    // A retry must be able to claim work again. No raw provider error or token is persisted.
    await receiptRef.delete();
    throw error;
  }
}
