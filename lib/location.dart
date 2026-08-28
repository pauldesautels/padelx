import 'dart:math' as math;

class MatchLocation {
  final String clubName, countryCode, country, region, city, area, placeId;
  final double? latitude, longitude;

  const MatchLocation({
    required this.clubName,
    required this.countryCode,
    required this.country,
    required this.region,
    required this.city,
    this.area = '',
    this.placeId = '',
    this.latitude,
    this.longitude,
  });

  bool get isValid =>
      clubName.trim().isNotEmpty &&
      countryCode.trim().length == 2 &&
      country.trim().isNotEmpty &&
      city.trim().isNotEmpty;

  String get localityLabel => <String>[
    if (area.trim().isNotEmpty) area.trim(),
    if (city.trim().isNotEmpty) city.trim(),
    if (region.trim().isNotEmpty &&
        region.trim().toLowerCase() != city.trim().toLowerCase())
      region.trim(),
    if (country.trim().isNotEmpty) country.trim(),
  ].join(', ');

  Map<String, Object> toMap() => {
    'clubName': clubName.trim(),
    'countryCode': countryCode.trim().toUpperCase(),
    'country': country.trim(),
    'region': region.trim(),
    'city': city.trim(),
    'area': area.trim(),
    if (placeId.trim().isNotEmpty) 'placeId': placeId.trim(),
    'latitude': ?latitude,
    'longitude': ?longitude,
  };

  factory MatchLocation.fromMap(
    Map<dynamic, dynamic> data, {
    String legacyClub = '',
    String legacyLocation = '',
  }) {
    final raw = data['location'];
    final location = raw is Map ? raw : const <dynamic, dynamic>{};
    String value(String key) =>
        location[key]?.toString().trim() ?? data[key]?.toString().trim() ?? '';
    double? coordinate(String key) {
      final value = location[key] ?? data[key];
      return value is num ? value.toDouble() : null;
    }

    return MatchLocation(
      clubName: value('clubName').isNotEmpty ? value('clubName') : legacyClub,
      countryCode: value('countryCode'),
      country: value('country'),
      region: value('region'),
      city: value('city'),
      area: value('area').isNotEmpty ? value('area') : legacyLocation,
      placeId: value('placeId'),
      latitude: coordinate('latitude'),
      longitude: coordinate('longitude'),
    );
  }
}

bool hasUsableCoordinates(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

double? distanceBetweenKm({
  required double? fromLatitude,
  required double? fromLongitude,
  required double? toLatitude,
  required double? toLongitude,
}) {
  if (!hasUsableCoordinates(fromLatitude, fromLongitude) ||
      !hasUsableCoordinates(toLatitude, toLongitude)) {
    return null;
  }
  const earthRadiusKm = 6371.0088;
  double radians(double degrees) => degrees * math.pi / 180;
  final latitudeDelta = radians(toLatitude! - fromLatitude!);
  final longitudeDelta = radians(toLongitude! - fromLongitude!);
  final a =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(radians(fromLatitude)) *
          math.cos(radians(toLatitude)) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  final normalized = a.clamp(0, 1).toDouble();
  return earthRadiusKm *
      2 *
      math.atan2(math.sqrt(normalized), math.sqrt(1 - normalized));
}

class DiscoveryLocation {
  final String country, countryCode, city, area;
  final double? latitude, longitude;
  const DiscoveryLocation({
    required this.country,
    required this.countryCode,
    required this.city,
    this.area = '',
    this.latitude,
    this.longitude,
  });
  bool get isConfigured => city.trim().isNotEmpty;
  Map<String, Object> toMap() => {
    'country': country.trim(),
    'countryCode': countryCode.trim().toUpperCase(),
    'city': city.trim(),
    'area': area.trim(),
    'latitude': ?latitude,
    'longitude': ?longitude,
  };
  factory DiscoveryLocation.fromMap(Object? raw) {
    final data = raw is Map ? raw : const <dynamic, dynamic>{};
    return DiscoveryLocation(
      country: data['country']?.toString().trim() ?? '',
      countryCode: data['countryCode']?.toString().trim() ?? '',
      city: data['city']?.toString().trim() ?? '',
      area: data['area']?.toString().trim() ?? '',
      latitude: data['latitude'] is num
          ? (data['latitude'] as num).toDouble()
          : null,
      longitude: data['longitude'] is num
          ? (data['longitude'] as num).toDouble()
          : null,
    );
  }

  factory DiscoveryLocation.fromMatchLocation(MatchLocation location) =>
      DiscoveryLocation(
        country: location.country,
        countryCode: location.countryCode,
        city: location.city,
        area: location.area,
        latitude: location.latitude,
        longitude: location.longitude,
      );
}

bool sameLocationValue(String actual, String? filter) =>
    filter == null ||
    filter.trim().isEmpty ||
    actual.trim().toLowerCase() == filter.trim().toLowerCase();
