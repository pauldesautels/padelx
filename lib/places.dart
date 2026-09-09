import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'location.dart';

const googlePlacesApiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
const googlePlacesIosBundleIdentifier = String.fromEnvironment(
  'FIREBASE_IOS_BUNDLE_ID',
);

class PlacePrediction {
  final String placeId;
  final String label;

  const PlacePrediction({required this.placeId, required this.label});
}

class GooglePlacesClient {
  static const _baseUrl = 'https://places.googleapis.com/v1';
  final String apiKey;
  final http.Client _client;
  final bool _isWeb;
  final TargetPlatform _targetPlatform;
  final String _iosBundleIdentifier;

  GooglePlacesClient({
    this.apiKey = googlePlacesApiKey,
    http.Client? client,
    bool? isWeb,
    TargetPlatform? targetPlatform,
    String iosBundleIdentifier = googlePlacesIosBundleIdentifier,
  }) : _client = client ?? http.Client(),
       _isWeb = isWeb ?? kIsWeb,
       _targetPlatform = targetPlatform ?? defaultTargetPlatform,
       _iosBundleIdentifier = iosBundleIdentifier;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<List<PlacePrediction>> autocomplete(
    String query, {
    required String sessionToken,
    bool citiesOnly = false,
  }) async {
    if (!isConfigured || query.trim().length < 2) return const [];
    final response = await _client.post(
      Uri.parse('$_baseUrl/places:autocomplete'),
      headers: _requestHeaders(contentType: 'application/json'),
      body: jsonEncode({
        'input': query.trim(),
        'sessionToken': sessionToken,
        if (citiesOnly) 'includedPrimaryTypes': ['(cities)'],
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logHttpFailure('autocomplete', response);
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
      headers: _requestHeaders(
        fieldMask: 'displayName,addressComponents,location,primaryType',
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logHttpFailure('placeDetails', response);
      throw PlacesException('Could not load that location.');
    }
    return matchLocationFromPlaceDetails(
      jsonDecode(response.body) as Map<String, dynamic>,
      placeId: placeId,
    );
  }

  Map<String, String> _requestHeaders({
    String? contentType,
    String? fieldMask,
  }) {
    final headers = <String, String>{'X-Goog-Api-Key': apiKey};
    if (contentType != null) headers['Content-Type'] = contentType;
    if (fieldMask != null) headers['X-Goog-FieldMask'] = fieldMask;
    if (!_isWeb && _targetPlatform == TargetPlatform.iOS) {
      final bundleIdentifier = _iosBundleIdentifier.trim();
      if (bundleIdentifier.isEmpty) {
        throw const PlacesConfigurationException(
          'Google Places iOS requests require FIREBASE_IOS_BUNDLE_ID.',
        );
      }
      headers['X-Ios-Bundle-Identifier'] = bundleIdentifier;
    }
    return headers;
  }

  void _logHttpFailure(String operation, http.Response response) {
    debugPrint(
      'Google Places HTTP failure: operation=$operation '
      'statusCode=${response.statusCode} '
      '${safeGooglePlacesErrorSummary(response.body, apiKey: apiKey)}',
    );
  }
}

@visibleForTesting
String safeGooglePlacesErrorSummary(String body, {String apiKey = ''}) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return 'responseBody=json-non-object';
    final error = decoded['error'];
    if (error is! Map) {
      return 'responseBody=json-without-supported-error-fields';
    }

    final fields = <String>[];
    void addField(String name, Object? value) {
      if (value == null) return;
      final sanitized = _sanitizeDiagnosticValue(value.toString(), apiKey);
      if (sanitized.isNotEmpty) fields.add('error.$name="$sanitized"');
    }

    addField('code', error['code']);
    addField('status', error['status']);
    addField('message', error['message']);
    return fields.isEmpty
        ? 'responseBody=json-without-supported-error-fields'
        : fields.join(' ');
  } on FormatException {
    return 'responseBody=non-json length=${body.length}';
  } catch (_) {
    return 'responseBody=unreadable length=${body.length}';
  }
}

String _sanitizeDiagnosticValue(String value, String apiKey) {
  var sanitized = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  if (apiKey.isNotEmpty) sanitized = sanitized.replaceAll(apiKey, '[REDACTED]');
  sanitized = sanitized
      .replaceAll(RegExp(r'AIza[0-9A-Za-z_-]{20,}'), '[REDACTED]')
      .replaceAll(
        RegExp(r'Bearer\s+[0-9A-Za-z._~+/-]+=*', caseSensitive: false),
        'Bearer [REDACTED]',
      );
  const maximumLength = 300;
  return sanitized.length <= maximumLength
      ? sanitized
      : '${sanitized.substring(0, maximumLength)}…';
}

class PlacesException implements Exception {
  final String message;
  const PlacesException(this.message);
  @override
  String toString() => message;
}

class PlacesConfigurationException implements Exception {
  final String message;
  const PlacesConfigurationException(this.message);
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
