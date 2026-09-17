import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveTrustedPlace } from '../functions/places_verification.js';

test('trusted place resolution returns only canonical address fields', async () => {
  let request;
  const result = await resolveTrustedPlace('place-private', 'test-key', async (url, options) => {
    request = { url, options };
    return {
      ok: true,
      async json() {
        return {
          id: 'place-private',
          displayName: { text: 'Private address' },
          formattedAddress: 'Synthetic address, Mexico',
          location: { latitude: 19.43, longitude: -99.13 },
          addressComponents: [{ shortText: 'MX', types: ['country'] }],
        };
      },
    };
  });
  assert.equal(request.url, 'https://places.googleapis.com/v1/places/place-private');
  assert.equal(request.options.headers['X-Goog-Api-Key'], 'test-key');
  assert.deepEqual(result, {
    placeId: 'place-private', latitude: 19.43, longitude: -99.13,
    formattedAddress: 'Synthetic address, Mexico', countryCode: 'MX',
    displayName: 'Private address',
  });
});

test('trusted place resolution rejects missing configuration and malformed responses', async () => {
  await assert.rejects(resolveTrustedPlace('place', '', async () => null),
    { code: 'failed-precondition' });
  await assert.rejects(resolveTrustedPlace('place', 'key', async () => ({
    ok: true, async json() { return { id: 'another-place' }; },
  })), { code: 'failed-precondition' });
});

test('trusted place resolution maps transport failures without exposing credentials', async () => {
  await assert.rejects(resolveTrustedPlace('place', 'secret-key', async () => {
    throw new Error('network');
  }), { code: 'unavailable', message: 'Venue verification is temporarily unavailable.' });
});
