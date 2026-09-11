import { HttpsError } from 'firebase-functions/v2/https';
import { requireActiveAccount } from './account_state.js';
import { validRequestId } from './messaging_policy.js';

export const ACCOUNT_ELIGIBILITY = 'accountEligibility';
export const AGE_ELIGIBILITY_VERSION = '18-plus-v1';
export const AGE_ELIGIBILITY_SCHEMA_VERSION = 1;

function validEligibility(data, uid) {
  return data?.uid === uid
    && data.age18Confirmed === true
    && data.ageEligibilityVersion === AGE_ELIGIBILITY_VERSION
    && data.schemaVersion === AGE_ELIGIBILITY_SCHEMA_VERSION
    && Number.isFinite(data.confirmedAt?.toMillis?.());
}

export async function getAgeEligibilityOperation(firestore, request) {
  const uid = await requireActiveAccount(firestore, request, { verified: false });
  const snapshot = await firestore.collection(ACCOUNT_ELIGIBILITY).doc(uid).get();
  return validEligibility(snapshot.data(), uid)
    ? { eligible: true, version: AGE_ELIGIBILITY_VERSION }
    : { eligible: false };
}

export async function recordAgeEligibilityOperation(firestore, request, now = new Date()) {
  const uid = await requireActiveAccount(firestore, request, { verified: false });
  const data = request?.data;
  if (!data || typeof data !== 'object' || Array.isArray(data)
      || Object.keys(data).length !== 3
      || data.confirmed !== true
      || data.version !== AGE_ELIGIBILITY_VERSION
      || !validRequestId(data.requestId)) {
    throw new HttpsError('invalid-argument', 'A valid age confirmation is required.');
  }
  const reference = firestore.collection(ACCOUNT_ELIGIBILITY).doc(uid);
  await firestore.runTransaction(async (transaction) => {
    const [current, barrier] = await transaction.getAll(
      reference, firestore.collection('accountDeletionBarriers').doc(uid));
    if (barrier.exists) {
      throw new HttpsError('permission-denied', 'Account deletion is in progress.');
    }
    if (validEligibility(current.data(), uid)) return;
    transaction.set(reference, {
      uid,
      age18Confirmed: true,
      ageEligibilityVersion: AGE_ELIGIBILITY_VERSION,
      confirmedAt: now,
      schemaVersion: AGE_ELIGIBILITY_SCHEMA_VERSION,
    });
  });
  return { recorded: true, version: AGE_ELIGIBILITY_VERSION };
}
