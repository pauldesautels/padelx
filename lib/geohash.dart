import 'dart:math' as math;

const _alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';

const discoveryInitialCellLimit = 10;
const discoveryFirstPageTarget = 12;

bool shouldExpandInitialDiscovery({
  required int requestedLimit,
  required int filteredResultCount,
  required bool anyCellHasMore,
}) {
  return requestedLimit == discoveryInitialCellLimit &&
      filteredResultCount < discoveryFirstPageTarget &&
      anyCellHasMore;
}

String encodeGeohash(double latitude, double longitude, {int precision = 4}) {
  var latMin = -90.0;
  var latMax = 90.0;
  var lonMin = -180.0;
  var lonMax = 180.0;
  var even = true;
  var bit = 0;
  var value = 0;
  final result = StringBuffer();
  while (result.length < precision) {
    if (even) {
      final mid = (lonMin + lonMax) / 2;
      if (longitude >= mid) {
        value = (value << 1) | 1;
        lonMin = mid;
      } else {
        value <<= 1;
        lonMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (latitude >= mid) {
        value = (value << 1) | 1;
        latMin = mid;
      } else {
        value <<= 1;
        latMax = mid;
      }
    }
    even = !even;
    bit++;
    if (bit == 5) {
      result.write(_alphabet[value]);
      bit = 0;
      value = 0;
    }
  }
  return result.toString();
}

/// Returns geohash prefixes covering the search bounding box. False positives
/// at the corners are removed with the existing exact distance calculation.
List<String> geohashCellsForRadius(
  double latitude,
  double longitude,
  double radiusKm,
) {
  final precision = radiusKm <= 25 ? 4 : 3;
  final latStep = precision == 4 ? 0.175 : 1.4;
  final lonStep = precision == 4 ? 0.35 : 1.4;
  final latDelta = radiusKm / 110.574;
  final cosine = math.cos(latitude * math.pi / 180).abs().clamp(0.01, 1.0);
  final lonDelta = radiusKm / (111.320 * cosine);
  final cells = <String>{};
  for (
    var lat = latitude - latDelta - latStep;
    lat <= latitude + latDelta + latStep;
    lat += latStep / 2
  ) {
    for (
      var lon = longitude - lonDelta - lonStep;
      lon <= longitude + lonDelta + lonStep;
      lon += lonStep / 2
    ) {
      cells.add(
        encodeGeohash(
          lat.clamp(-90, 90),
          _wrapLongitude(lon),
          precision: precision,
        ),
      );
    }
  }
  return cells.toList()..sort();
}

double _wrapLongitude(double value) {
  var longitude = value;
  while (longitude < -180) {
    longitude += 360;
  }
  while (longitude > 180) {
    longitude -= 360;
  }
  return longitude;
}
