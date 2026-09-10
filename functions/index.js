import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getStorage } from 'firebase-admin/storage';
import { onCall } from 'firebase-functions/v2/https';
import { admitAccountDeletion, lockDeletionAuth } from './account_deletion.js';
import { getFirestore } from 'firebase-admin/firestore';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { encodeGeohash } from './aggregate_helpers.js';
import { backendEnvironment, assertContributionAccountingReady, assertPhase9Enabled } from './backend_environment.js';
import { reconcileRating } from './rating_contributions.js';
import { reconcilePlayedWithMatch, recoverPlayedWithMatches } from './played_with_projection.js';
import { requestFriendOperation, respondToFriendRequestOperation,
  cancelFriendRequestOperation, removeFriendOperation } from './friendship.js';
import { blockPlayerOperation, listBlockedPlayersOperation, unblockPlayerOperation } from './blocks.js';
import { getRelationshipPoliciesOperation } from './friendship_policy.js';
import { ensureDirectConversationOperation, ensureMatchConversationOperation,
  listConversationsOperation, listMessagesOperation, markConversationReadOperation,
  sendMessageOperation } from './messaging.js';
import { createPlayAgainInvitationOperation, dismissPlayAgainInvitationOperation,
  reconcilePlayAgainInvitesForMatch } from './play_again.js';
import { discoverPlayersOperation } from './player_discovery.js';

function backendFirestore() {
  const environment = backendEnvironment();
  const app = getApps().find((candidate) => candidate.name === 'padelx-trusted')
    ?? initializeApp({ projectId: environment.projectId,
      storageBucket: `${environment.projectId}.appspot.com` }, 'padelx-trusted');
  if (app.options.projectId !== environment.projectId) throw new Error('Backend project mismatch.');
  return { firestore: getFirestore(app), auth: getAuth(app), bucket: getStorage(app).bucket(), environment };
}

export async function handleMatchLocationWritten(event) {
  const { firestore } = backendFirestore();
  const ref = firestore.collection('matches').doc(event.params.matchId);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) return;
    const data = snapshot.data();
    const latitude = data.location?.latitude;
    const longitude = data.location?.longitude;
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return;
    const geoHash3 = encodeGeohash(latitude, longitude, 3);
    const geoHash4 = encodeGeohash(latitude, longitude, 4);
    if (data.geoHash3 === geoHash3 && data.geoHash4 === geoHash4) return;
    transaction.update(ref, { geoHash3, geoHash4 });
  });
}

export const indexMatchLocation = onDocumentWritten('matches/{matchId}', handleMatchLocationWritten);

export async function handlePlayerRatingWritten(event) {
  const { firestore, environment } = backendFirestore();
  assertContributionAccountingReady(environment);
  const { matchId, raterUid, ratedUid } = event.params;
  // Event snapshots are deliberately ignored; even stale create/delete events
  // reconcile the currently committed source and contribution.
  return reconcileRating(firestore, `matches/${matchId}/ratingRaters/${raterUid}/ratings/${ratedUid}`);
}

export const aggregatePlayerRating = onDocumentWritten({
  document: 'matches/{matchId}/ratingRaters/{raterUid}/ratings/{ratedUid}',
  retry: true,
}, handlePlayerRatingWritten);

export const projectPlayedWithMatch = onDocumentWritten({
  document: 'matches/{matchId}', retry: true, maxInstances: 4,
}, async (event) => {
  const { firestore } = backendFirestore();
  assertPhase9Enabled(backendEnvironment());
  await reconcilePlayedWithMatch(firestore, event.params.matchId);
});

// App Check is enforced for every non-emulator invocation.
export const requestAccountDeletion = onCall({
  enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== 'true',
}, async (request) => {
  const { firestore, auth } = backendFirestore();
  return admitAccountDeletion(firestore, auth, request);
});

const socialCallable = (operation) => onCall({
  enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== 'true',
}, async (request) => {
  const { firestore } = backendFirestore();
  assertPhase9Enabled(backendEnvironment());
  return operation(firestore, request);
});

export const requestFriend = socialCallable(requestFriendOperation);
export const respondToFriendRequest = socialCallable(respondToFriendRequestOperation);
export const cancelFriendRequest = socialCallable(cancelFriendRequestOperation);
export const removeFriend = socialCallable(removeFriendOperation);
export const blockPlayer = socialCallable(blockPlayerOperation);
export const unblockPlayer = socialCallable(unblockPlayerOperation);
export const listBlockedPlayers = socialCallable(listBlockedPlayersOperation);
export const getRelationshipPolicies = socialCallable(getRelationshipPoliciesOperation);
export const ensureDirectConversation = socialCallable(ensureDirectConversationOperation);
export const ensureMatchConversation = socialCallable(ensureMatchConversationOperation);
export const sendMessage = socialCallable(sendMessageOperation);
export const listMessages = socialCallable(listMessagesOperation);
export const listConversations = socialCallable(listConversationsOperation);
export const markConversationRead = socialCallable(markConversationReadOperation);
export const createPlayAgainInvitation = socialCallable(createPlayAgainInvitationOperation);
export const dismissPlayAgainInvitation = socialCallable(dismissPlayAgainInvitationOperation);
export const discoverPlayers = socialCallable(discoverPlayersOperation);

export const reconcilePlayAgainInvitations = onDocumentWritten({
  document: 'matches/{matchId}', retry: true, maxInstances: 4,
}, async (event) => {
  const { firestore } = backendFirestore();
  assertPhase9Enabled(backendEnvironment());
  await reconcilePlayAgainInvitesForMatch(firestore, event.params.matchId);
});

// At-least-once delivery retries Auth lockdown after a lost callable response
// or crash. This trigger does not dispatch or perform account cleanup.
export const lockAccountDeletionAuth = onDocumentCreated({
  document: 'accountDeletionOutbox/{uid}', retry: true,
}, async (event) => {
  const { firestore, auth } = backendFirestore();
  return lockDeletionAuth(firestore, auth, event.params.uid);
});

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { recoverAccountDeletions } from './account_deletion_dispatch.js';
import { deletedAuthFallback } from './account_deletion_auth_trigger.js';
export const recoverPlayedWithProjection = onSchedule({
  schedule: 'every 5 minutes', timeoutSeconds: 120, maxInstances: 1,
}, async () => {
  const { firestore } = backendFirestore();
  assertPhase9Enabled(backendEnvironment());
  await recoverPlayedWithMatches(firestore);
});
export const recoverAccountDeletionJobs = onSchedule({
  schedule: 'every 1 minutes', timeoutSeconds: 120, maxInstances: 1,
}, async () => {
  const { firestore, auth, bucket } = backendFirestore();
  await recoverAccountDeletions(firestore, auth, bucket);
});
export const cleanupDeletedAuthUser = deletedAuthFallback(backendFirestore);
