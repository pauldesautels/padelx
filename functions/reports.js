import { HttpsError } from 'firebase-functions/v2/https';
import { requireActiveAccount, DELETION_BARRIERS } from './account_state.js';
import { validEligibility } from './eligibility.js';
import { validRelationshipUid } from './friendship_policy.js';
import { conversationAccess, requireMessagingActor } from './messaging.js';
import {
  REPORT_SCHEMA_VERSION, REPORT_ROLLING_MAX, REPORT_ROLLING_WINDOW_MS,
  REPORT_SUBJECT_COOLDOWN_MS, normalizeReportPayload, reportDedupeKey,
  reportIdFor, reporterRateLimitId, subjectRateLimitId,
} from './report_policy.js';

const dateFrom = (value) => value?.toDate?.() ?? value;
const presentString = (value) => typeof value === 'string';
const optionalField = (target, key, value, valid = (candidate) => candidate != null) => {
  if (valid(value)) target[key] = value;
};

async function requireReporter(firestore, request) {
  const uid = await requireActiveAccount(firestore, request);
  const [user, eligibility] = await firestore.getAll(
    firestore.doc(`users/${uid}`), firestore.doc(`accountEligibility/${uid}`));
  if (!user.exists || user.data()?.active === false) {
    throw new HttpsError('failed-precondition', 'Account setup is incomplete.');
  }
  if (!validEligibility(eligibility.data(), uid)) {
    throw new HttpsError('failed-precondition', 'Age eligibility is required.');
  }
  return uid;
}

async function playerSubject(firestore, reporterUid, subjectId) {
  if (subjectId === reporterUid) {
    throw new HttpsError('invalid-argument', 'You cannot report yourself.');
  }
  const [user, profile, barrier] = await firestore.getAll(
    firestore.doc(`users/${subjectId}`), firestore.doc(`publicProfiles/${subjectId}`),
    firestore.doc(`${DELETION_BARRIERS}/${subjectId}`));
  if (!user.exists || user.data()?.active === false || !profile.exists || barrier.exists
      || profile.data()?.uid !== subjectId) {
    throw new HttpsError('not-found', 'Player is unavailable.');
  }
  const data = profile.data();
  const evidence = {};
  optionalField(evidence, 'displayName', data.displayName, presentString);
  optionalField(evidence, 'bio', data.bio, presentString);
  optionalField(evidence, 'avatarVersion', data.avatarVersion,
    (value) => Number.isSafeInteger(value) && value >= 0);
  return { subjectOwnerUid: subjectId, evidence };
}

async function messageSubject(firestore, request, reporterUid, payload, now) {
  const messagingUid = await requireMessagingActor(firestore, request);
  if (messagingUid !== reporterUid) throw new HttpsError('permission-denied', 'Reporting is unavailable.');
  const conversationRef = firestore.doc(`conversations/${payload.conversationId}`);
  const conversationSnapshot = await conversationRef.get();
  if (!conversationSnapshot.exists) throw new HttpsError('not-found', 'Message is unavailable.');
  const conversation = conversationSnapshot.data();
  const access = await conversationAccess(firestore, reporterUid, conversation, now);
  if (!access.allowed) throw new HttpsError('permission-denied', 'Message is unavailable.');
  const message = await conversationRef.collection('messages').doc(payload.subjectId).get();
  if (!message.exists) throw new HttpsError('not-found', 'Message is unavailable.');
  const data = message.data();
  if (!validRelationshipUid(data.senderUid) || data.senderUid === reporterUid
      || !presentString(data.text) || !Number.isFinite(data.createdAt?.toMillis?.())
      || !['direct', 'match'].includes(conversation.type)) {
    throw new HttpsError('failed-precondition', 'Message is unavailable.');
  }
  return {
    subjectOwnerUid: data.senderUid,
    conversationId: payload.conversationId,
    conversationType: conversation.type,
    ...(conversation.type === 'match' && presentString(conversation.matchId)
      ? { matchId: conversation.matchId } : {}),
    evidence: {
      messageId: message.id,
      senderUid: data.senderUid,
      text: data.text,
      createdAt: data.createdAt,
      conversationType: conversation.type,
    },
  };
}

async function matchSubject(firestore, reporterUid, subjectId) {
  const snapshot = await firestore.doc(`matches/${subjectId}`).get();
  if (!snapshot.exists) throw new HttpsError('not-found', 'Match is unavailable.');
  const data = snapshot.data();
  const organizerUid = data.creatorUid || data.createdBy;
  if (!validRelationshipUid(organizerUid)) {
    throw new HttpsError('failed-precondition', 'Match is unavailable.');
  }
  if (organizerUid === reporterUid) {
    throw new HttpsError('invalid-argument', 'You cannot report your own match.');
  }
  const location = data.location && typeof data.location === 'object' ? data.location : {};
  const evidence = { organizerUid };
  optionalField(evidence, 'title', data.title, presentString);
  optionalField(evidence, 'clubName', data.clubName ?? data.club, presentString);
  optionalField(evidence, 'scheduledAt', data.scheduledAt,
    (value) => Number.isFinite(value?.toMillis?.()));
  for (const key of ['countryCode', 'city', 'area']) {
    optionalField(evidence, key, location[key], presentString);
  }
  return { subjectOwnerUid: organizerUid, evidence };
}

async function subjectContext(firestore, request, reporterUid, payload, now) {
  if (payload.subjectType === 'player') {
    return playerSubject(firestore, reporterUid, payload.subjectId);
  }
  if (payload.subjectType === 'message') {
    return messageSubject(firestore, request, reporterUid, payload, now);
  }
  return matchSubject(firestore, reporterUid, payload.subjectId);
}

export async function submitReportOperation(firestore, request, now = new Date()) {
  const reporterUid = await requireReporter(firestore, request);
  const payload = normalizeReportPayload(request?.data);
  const reportId = reportIdFor(reporterUid, payload.requestId);
  const reportRef = firestore.doc(`reports/${reportId}`);
  const existing = await reportRef.get();
  if (existing.exists) {
    if (existing.data()?.reporterUid !== reporterUid
        || existing.data()?.requestId !== payload.requestId) {
      throw new HttpsError('internal', 'Report submission failed.');
    }
    return { submitted: true, duplicate: true };
  }

  const context = await subjectContext(firestore, request, reporterUid, payload, now);
  const dedupeKey = reportDedupeKey(reporterUid, payload);
  const subjectLimitRef = firestore.doc(`reportRateLimits/${subjectRateLimitId(dedupeKey)}`);
  const reporterLimitRef = firestore.doc(`reportRateLimits/${reporterRateLimitId(reporterUid)}`);
  let duplicate = false;
  await firestore.runTransaction(async (transaction) => {
    const [current, subjectLimit, reporterLimit] = await transaction.getAll(
      reportRef, subjectLimitRef, reporterLimitRef);
    if (current.exists) {
      if (current.data()?.reporterUid !== reporterUid
          || current.data()?.requestId !== payload.requestId) {
        throw new HttpsError('internal', 'Report submission failed.');
      }
      duplicate = true;
      return;
    }
    const subjectLimitData = subjectLimit.data();
    const subjectExpiresAt = dateFrom(subjectLimitData?.expiresAt);
    const subjectDuplicate = subjectLimit.exists && (payload.subjectType === 'message'
      || (subjectExpiresAt instanceof Date && subjectExpiresAt > now));
    if (subjectDuplicate) {
      throw new HttpsError('already-exists', 'A report for this item was already submitted.');
    }
    const recent = Array.isArray(reporterLimit.data()?.submittedAt)
      ? reporterLimit.data().submittedAt.map(dateFrom).filter((date) => date instanceof Date
        && now - date < REPORT_ROLLING_WINDOW_MS && now >= date) : [];
    if (recent.length >= REPORT_ROLLING_MAX) {
      throw new HttpsError('resource-exhausted', 'Report submission is temporarily unavailable.');
    }
    const report = {
      schemaVersion: REPORT_SCHEMA_VERSION,
      reporterUid,
      subjectType: payload.subjectType,
      subjectId: payload.subjectId,
      subjectOwnerUid: context.subjectOwnerUid,
      reason: payload.reason,
      createdAt: now,
      updatedAt: now,
      status: 'open',
      requestId: payload.requestId,
      dedupeKey,
      ...(payload.details ? { details: payload.details } : {}),
      ...(context.conversationId ? { conversationId: context.conversationId } : {}),
      ...(context.conversationType ? { conversationType: context.conversationType } : {}),
      ...(context.matchId ? { matchId: context.matchId } : {}),
      evidence: context.evidence,
    };
    transaction.create(reportRef, report);
    transaction.set(reporterLimitRef, { submittedAt: [...recent, now], updatedAt: now });
    transaction.set(subjectLimitRef, {
      subjectType: payload.subjectType,
      dedupeKey,
      createdAt: now,
      updatedAt: now,
      ...(payload.subjectType === 'message'
        ? {} : { expiresAt: new Date(now.getTime() + REPORT_SUBJECT_COOLDOWN_MS) }),
    });
  });
  return { submitted: true, duplicate };
}
