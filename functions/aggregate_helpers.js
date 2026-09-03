const alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';

export function encodeGeohash(latitude, longitude, precision) {
  let lat = [-90, 90]; let lon = [-180, 180]; let even = true;
  let bit = 0; let value = 0; let result = '';
  while (result.length < precision) {
    const range = even ? lon : lat;
    const coordinate = even ? longitude : latitude;
    const mid = (range[0] + range[1]) / 2;
    value = (value << 1) | (coordinate >= mid ? 1 : 0);
    if (coordinate >= mid) range[0] = mid; else range[1] = mid;
    even = !even;
    if (++bit === 5) { result += alphabet[value]; bit = 0; value = 0; }
  }
  return result;
}

export function ratingAggregateAfter(current, rating) {
  const count = Number(current.ratingCount ?? 0) + 1;
  const sum = Number(current.ratingSum ?? 0) + rating;
  return { ratingCount: count, ratingSum: sum, ratingAverage: sum / count };
}
