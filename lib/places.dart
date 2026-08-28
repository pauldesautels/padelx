import 'dart:convert';

import 'package:http/http.dart' as http;

import 'location.dart';

const googlePlacesApiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');

class PlacePrediction {
  final String placeId;
  final String label;

  const PlacePrediction({required this.placeId, required this.label});
}

class GooglePlacesClient {
  static const _baseUrl = 'https://places.googleapis.com/v1';
  final String apiKey;
  final http.Client _client;

  GooglePlacesClient({this.apiKey = googlePlacesApiKey, http.Client? client})
    : _client = client ?? http.Client();

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<List<PlacePrediction>> autocomplete(
    String query, {
    required String sessionToken,
    bool citiesOnly = false,
  }) async {
    if (!isConfigured || query.trim().length < 2) return const [];
    final response = await _client.post(
      Uri.parse('$_baseUrl/places:autocomplete'),
      headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': apiKey},
      body: jsonEncode({
        'input': query.trim(),
        'sessionToken': sessionToken,
        if (citiesOnly) 'includedPrimaryTypes': ['(cities)'],
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlacesException(
        'Location suggestions are temporarily unavailable.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['suggestions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => item['placePrediction'])
        .whereType<Map<String, dynamic>>()
        .map(
          (prediction) => PlacePrediction(
            placeId: prediction['placeId']?.toString() ?? '',
            label: (prediction['text'] as Map?)?['text']?.toString() ?? '',
          ),
        )
        .where((prediction) => prediction.placeId.isNotEmpty)
        .toList();
  }

  Future<MatchLocation> placeDetails(
    String placeId, {
    required String sessionToken,
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/places/$placeId?sessionToken=$sessionToken'),
      headers: {
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'displayName,addressComponents,location,primaryType',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlacesException('Could not load that location.');
    }
    return matchLocationFromPlaceDetails(
      jsonDecode(response.body) as Map<String, dynamic>,
      placeId: placeId,
    );
  }
}

class PlacesException implements Exception {
  final String message;
  const PlacesException(this.message);
  @override
  String toString() => message;
}

MatchLocation matchLocationFromPlaceDetails(
  Map<String, dynamic> data, {
  String placeId = '',
}) {
  final components = (data['addressComponents'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>();
  Map<String, dynamic>? component(String type) {
    for (final value in components) {
      final types = (value['types'] as List<dynamic>? ?? const []).map(
        (item) => item.toString(),
      );
      if (types.contains(type)) return value;
    }
    return null;
  }

  String longName(String type) =>
      component(type)?['longText']?.toString().trim() ?? '';
  String shortName(String type) =>
      component(type)?['shortText']?.toString().trim() ?? '';
  String firstOf(Iterable<String> types) {
    for (final type in types) {
      final value = longName(type);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  final city = firstOf(const [
    'locality',
    'postal_town',
    'administrative_area_level_2',
  ]);
  final area = firstOf(const [
    'neighborhood',
    'sublocality_level_1',
    'sublocality',
  ]);
  final coordinates = data['location'] as Map?;
  return MatchLocation(
    clubName: (data['displayName'] as Map?)?['text']?.toString().trim() ?? '',
    countryCode: shortName('country').toUpperCase(),
    country: longName('country'),
    region: longName('administrative_area_level_1'),
    city: city,
    area: area,
    placeId: placeId,
    latitude: (coordinates?['latitude'] as num?)?.toDouble(),
    longitude: (coordinates?['longitude'] as num?)?.toDouble(),
  );
}
