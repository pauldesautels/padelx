import { HttpsError } from 'firebase-functions/v2/https';

const text = (value, maximum = 300) => typeof value === 'string'
  && value.trim().length > 0 && value.trim().length <= maximum ? value.trim() : null;

export async function resolveTrustedPlace(placeId, apiKey, fetcher = fetch) {
  const id = text(placeId, 256);
  const key = text(apiKey, 512);
  if (!id || !key || id.includes('/')) {
    throw new HttpsError('failed-precondition', 'Venue verification is unavailable.');
  }
  let response;
  try {
    response = await fetcher(`https://places.googleapis.com/v1/places/${encodeURIComponent(id)}`, {
      headers: {
        'X-Goog-Api-Key': key,
        'X-Goog-FieldMask': 'id,displayName,formattedAddress,addressComponents,location',
      },
    });
  } catch {
    throw new HttpsError('unavailable', 'Venue verification is temporarily unavailable.');
  }
  if (!response.ok) {
    throw new HttpsError('unavailable', 'Venue verification is temporarily unavailable.');
  }
  const data = await response.json();
  const latitude = data?.location?.latitude;
  const longitude = data?.location?.longitude;
  const formattedAddress = text(data?.formattedAddress);
  if (data?.id !== id || !Number.isFinite(latitude) || !Number.isFinite(longitude)
      || !formattedAddress) {
    throw new HttpsError('failed-precondition', 'That venue could not be verified.');
  }
  const countryCode = (data.addressComponents ?? [])
    .find((component) => component?.types?.includes('country'))?.shortText?.toUpperCase() ?? '';
  return { placeId: id, latitude, longitude, formattedAddress, countryCode,
    displayName: text(data?.displayName?.text, 120) ?? '' };
}
