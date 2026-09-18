import { createHash } from 'node:crypto';
import { HttpsError } from 'firebase-functions/v2/https';
import { requireActiveAccount, requireSignedIn } from './account_state.js';
import { backendEnvironment } from './backend_environment.js';

export const PUSH_DEVICES = 'pushDevices';
export const STAGING_IOS_BUNDLES = Object.freeze([
  'com.padelx.app.staging',
  'com.padelx.app.devicetest',
]);
export const STAGING_ANDROID_PACKAGES = Object.freeze(['com.example.padelx']);
const STAGING_SENDER_ID = '708585002488';
const MIN_TOKEN_LENGTH = 20;
const MAX_TOKEN_LENGTH = 4096;
const SUPPORTED_LOCALES = Object.freeze(['en', 'es-MX']);

function requiredString(value, name, { min = 1, max = 512 } = {}) {
  if (typeof value !== 'string' || value.length < min || value.length > max
      || value.trim() !== value || /[\u0000-\u001f\u007f]/.test(value)) {
    throw new HttpsError('invalid-argument', `Invalid ${name}.`);
  }
  return value;
}

export function pushTokenHash(token) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

export function validatePushDeviceIdentity(request, environment = backendEnvironment()) {
  const data = request?.data ?? {};
  const token = requiredString(data.token, 'push token', {
    min: MIN_TOKEN_LENGTH,
    max: MAX_TOKEN_LENGTH,
  });
  if (/\s/.test(token)) throw new HttpsError('invalid-argument', 'Invalid push token.');
  if (!['ios', 'android'].includes(data.platform)) {
    throw new HttpsError('invalid-argument', 'Unsupported push platform.');
  }

  const projectId = requiredString(data.firebaseProjectId, 'Firebase project', { max: 128 });
  const firebaseAppId = requiredString(data.firebaseAppId, 'Firebase app', { max: 256 });
  const applicationIdentity = data.platform === 'ios'
    ? { bundleId: requiredString(data.bundleId, 'bundle identifier', { max: 255 }) }
    : { packageName: requiredString(data.packageName, 'package name', { max: 255 }) };
  const locale = SUPPORTED_LOCALES.includes(data.locale) ? data.locale : 'en';
  if (projectId !== environment.projectId) {
    throw new HttpsError('failed-precondition', 'Push environment mismatch.');
  }
  if (environment.mode === 'staging') {
    const validApp = data.platform === 'ios'
      ? STAGING_IOS_BUNDLES.includes(applicationIdentity.bundleId)
        && firebaseAppId.startsWith(`1:${STAGING_SENDER_ID}:ios:`)
      : STAGING_ANDROID_PACKAGES.includes(applicationIdentity.packageName)
        && firebaseAppId.startsWith(`1:${STAGING_SENDER_ID}:android:`);
    if (!validApp) {
      throw new HttpsError('failed-precondition', 'Push app identity mismatch.');
    }
    if (request?.app?.appId !== firebaseAppId) {
      throw new HttpsError('failed-precondition', 'Push attestation identity mismatch.');
    }
  } else if (environment.mode === 'emulator') {
    const validIdentity = data.platform === 'ios'
      ? STAGING_IOS_BUNDLES.includes(applicationIdentity.bundleId)
      : STAGING_ANDROID_PACKAGES.includes(applicationIdentity.packageName);
    if (!validIdentity) {
      throw new HttpsError('failed-precondition', 'Push app identity mismatch.');
    }
    if (request?.app?.appId && request.app.appId !== firebaseAppId) {
      throw new HttpsError('failed-precondition', 'Push attestation identity mismatch.');
    }
  } else {
    throw new HttpsError('failed-precondition', 'Push registration is unavailable.');
  }
  return { token, platform: data.platform, projectId, firebaseAppId, locale,
    ...applicationIdentity };
}

export async function registerPushDeviceOperation(firestore, request) {
  const uid = await requireActiveAccount(firestore, request);
  const identity = validatePushDeviceIdentity(request);
  const now = request?.rawRequest?.pushNow ?? new Date();
  const ref = firestore.collection(PUSH_DEVICES).doc(pushTokenHash(identity.token));
  await firestore.runTransaction(async (transaction) => {
    const existing = await transaction.get(ref);
    transaction.set(ref, {
      uid,
      token: identity.token,
      platform: identity.platform,
      firebaseProjectId: identity.projectId,
      firebaseAppId: identity.firebaseAppId,
      locale: identity.locale,
      ...(identity.platform === 'ios'
        ? { bundleId: identity.bundleId }
        : { packageName: identity.packageName }),
      enabled: true,
      createdAt: existing.data()?.createdAt ?? now,
      updatedAt: now,
      lastSeenAt: now,
    });
  });
  return { registered: true };
}

export async function unregisterPushDeviceOperation(firestore, request) {
  requireSignedIn(request);
  const identity = validatePushDeviceIdentity(request);
  const ref = firestore.collection(PUSH_DEVICES).doc(pushTokenHash(identity.token));
  await firestore.runTransaction(async (transaction) => {
    const existing = await transaction.get(ref);
    // Possession of the exact project/app-bound token is sufficient to remove
    // stale ownership after an account switch. Never reveal the prior owner.
    if (existing.exists) transaction.delete(ref);
  });
  return { unregistered: true };
}
