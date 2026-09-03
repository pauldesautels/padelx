import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { encodeGeohash, ratingAggregateAfter } from './aggregate_helpers.js';

initializeApp();

export async function handleMatchLocationWritten(event) {
  const snapshot = event.data?.after;
  if (!snapshot?.exists) return;
  const data = snapshot.data();
  const latitude = data.location?.latitude;
  const longitude = data.location?.longitude;
  if (typeof latitude !== 'number' || typeof longitude !== 'number') return;
  const geoHash3 = encodeGeohash(latitude, longitude, 3);
  const geoHash4 = encodeGeohash(latitude, longitude, 4);
  if (data.geoHash3 === geoHash3 && data.geoHash4 === geoHash4) return;
  await snapshot.ref.update({ geoHash3, geoHash4 });
}

export const indexMatchLocation = onDocumentWritten(
  'matches/{matchId}',
  handleMatchLocationWritten,
);

export async function handlePlayerRatingCreated(event) {
  const rating = event.data?.data()?.rating;
  const ratedUid = event.params.ratedUid;
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) return;
  const firestore = getFirestore();
  const profile = firestore.collection('publicProfiles').doc(ratedUid);
  const eventMarker = firestore.collection('ratingAggregationEvents').doc(event.id);
  await firestore.runTransaction(async (transaction) => {
    const marker = await transaction.get(eventMarker);
    if (marker.exists) return;
    const snapshot = await transaction.get(profile);
    if (!snapshot.exists) throw new Error(`Missing public profile for ${ratedUid}`);
    transaction.update(profile, ratingAggregateAfter(snapshot.data(), rating));
    transaction.create(eventMarker, {
      ratedUid,
      ratingPath: event.data.ref.path,
      processedAt: new Date(),
    });
  });
}

export const aggregatePlayerRating = onDocumentCreated(
  'matches/{matchId}/ratingRaters/{raterUid}/ratings/{ratedUid}',
  handlePlayerRatingCreated,
);
