class MatchLocation {
  final String clubName, countryCode, country, region, city, area;
  final double? latitude, longitude;

  const MatchLocation({
    required this.clubName,
    required this.countryCode,
    required this.country,
    required this.region,
    required this.city,
    this.area = '',
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
      latitude: coordinate('latitude'),
      longitude: coordinate('longitude'),
    );
  }
}

class DiscoveryLocation {
  final String country, countryCode, city;
  const DiscoveryLocation({
    required this.country,
    required this.countryCode,
    required this.city,
  });
  bool get isConfigured => city.trim().isNotEmpty;
  Map<String, String> toMap() => {
    'country': country.trim(),
    'countryCode': countryCode.trim().toUpperCase(),
    'city': city.trim(),
  };
  factory DiscoveryLocation.fromMap(Object? raw) {
    final data = raw is Map ? raw : const <dynamic, dynamic>{};
    return DiscoveryLocation(
      country: data['country']?.toString().trim() ?? '',
      countryCode: data['countryCode']?.toString().trim() ?? '',
      city: data['city']?.toString().trim() ?? '',
    );
  }
}

bool sameLocationValue(String actual, String? filter) =>
    filter == null ||
    filter.trim().isEmpty ||
    actual.trim().toLowerCase() == filter.trim().toLowerCase();
