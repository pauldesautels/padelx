import { HttpsError } from 'firebase-functions/v2/https';
import { requireActiveAccount } from './account_state.js';
import { validRequestId } from './messaging_policy.js';

export const LEGAL_ACCEPTANCE = 'accountLegalAcceptance';
export const LEGAL_SCHEMA_VERSION = 1;
export const TERMS_VERSION = 'terms-beta-v2';
export const PRIVACY_VERSION = 'privacy-beta-v2';
export const COMMUNITY_VERSION = 'community-beta-v2';

const accepted = (data, uid) => data?.uid === uid
  && data.schemaVersion === LEGAL_SCHEMA_VERSION
  && data.termsVersion === TERMS_VERSION
  && data.privacyVersion === PRIVACY_VERSION
  && data.communityVersion === COMMUNITY_VERSION
  && Number.isFinite(data.acceptedAt?.toMillis?.());

export async function getLegalAcceptanceOperation(firestore, request) {
  const uid = await requireActiveAccount(firestore, request, { verified: false });
  const snapshot = await firestore.collection(LEGAL_ACCEPTANCE).doc(uid).get();
  return accepted(snapshot.data(), uid)
    ? { accepted: true, termsVersion: TERMS_VERSION, privacyVersion: PRIVACY_VERSION,
      communityVersion: COMMUNITY_VERSION }
    : { accepted: false };
}
export async function recordLegalAcceptanceOperation(firestore, request, now = new Date()) {
  const uid = await requireActiveAccount(firestore, request, { verified: false });
  const data = request?.data;
  if (!data || typeof data !== 'object' || Array.isArray(data)
      || Object.keys(data).length !== 5 || data.termsVersion !== TERMS_VERSION
      || data.privacyVersion !== PRIVACY_VERSION || data.communityVersion !== COMMUNITY_VERSION
      || data.acknowledged !== true || !validRequestId(data.requestId)) {
    throw new HttpsError('invalid-argument', 'Current legal acknowledgement required.');
  }
  const reference = firestore.collection(LEGAL_ACCEPTANCE).doc(uid);
  await firestore.runTransaction(async (transaction) => {
    const [current, barrier] = await transaction.getAll(
      reference, firestore.collection('accountDeletionBarriers').doc(uid));
    if (barrier.exists) throw new HttpsError('permission-denied', 'Account deletion is in progress.');
    if (accepted(current.data(), uid)) return;
    transaction.set(reference, { uid, termsVersion: TERMS_VERSION,
      privacyVersion: PRIVACY_VERSION, communityVersion: COMMUNITY_VERSION,
      acceptedAt: now, schemaVersion: LEGAL_SCHEMA_VERSION });
  });
  return { recorded: true, termsVersion: TERMS_VERSION, privacyVersion: PRIVACY_VERSION,
    communityVersion: COMMUNITY_VERSION };
}
