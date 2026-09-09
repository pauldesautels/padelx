import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:padelx/places.dart';

const _apiKey = 'test-places-key';
const _bundleIdentifier = 'com.padelx.app.devicetest';

void main() {
  test(
    'iOS autocomplete sends native identity and preserves behavior',
    () async {
      late http.Request request;
      final client = _client(
        platform: TargetPlatform.iOS,
        handler: (value) async {
          request = value;
          return http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'mexico-city',
                    'text': {'text': 'Mexico City, Mexico'},
                  },
                },
              ],
            }),
            200,
          );
        },
      );

      final predictions = await client.autocomplete(
        ' Mexico City ',
        sessionToken: 'session-one',
        citiesOnly: true,
      );

      expect(request.headers['x-goog-api-key'], _apiKey);
      expect(request.headers['x-ios-bundle-identifier'], _bundleIdentifier);
      expect(request.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(request.body), {
        'input': 'Mexico City',
        'sessionToken': 'session-one',
        'includedPrimaryTypes': ['(cities)'],
      });
      expect(predictions, hasLength(1));
      expect(predictions.single.placeId, 'mexico-city');
      expect(predictions.single.label, 'Mexico City, Mexico');
    },
  );

  test(
    'iOS Place Details sends native identity and preserves parsing',
    () async {
      late http.Request request;
      final client = _client(
        platform: TargetPlatform.iOS,
        handler: (value) async {
          request = value;
          return http.Response(jsonEncode(_placeDetailsResponse), 200);
        },
      );

      final location = await client.placeDetails(
        'mexico-city',
        sessionToken: 'session-two',
      );

      expect(request.headers['x-goog-api-key'], _apiKey);
      expect(request.headers['x-ios-bundle-identifier'], _bundleIdentifier);
      expect(
        request.headers['x-goog-fieldmask'],
        'displayName,addressComponents,location,primaryType',
      );
      expect(location.country, 'Mexico');
      expect(location.countryCode, 'MX');
      expect(location.city, 'Mexico City');
      expect(location.latitude, 19.4326);
      expect(location.longitude, -99.1332);
      expect(location.placeId, 'mexico-city');
    },
  );

  for (final operation in ['autocomplete', 'placeDetails']) {
    test('web $operation does not send iOS identity', () async {
      late http.Request request;
      final client = _client(
        isWeb: true,
        platform: TargetPlatform.iOS,
        handler: (value) async {
          request = value;
          return operation == 'autocomplete'
              ? http.Response('{"suggestions":[]}', 200)
              : http.Response(jsonEncode(_placeDetailsResponse), 200);
        },
      );

      if (operation == 'autocomplete') {
        await client.autocomplete('Mexico', sessionToken: 'session');
      } else {
        await client.placeDetails('mexico-city', sessionToken: 'session');
      }

      expect(request.headers, isNot(contains('x-ios-bundle-identifier')));
      expect(request.headers['x-goog-api-key'], _apiKey);
    });
  }

  test('non-iOS native platforms do not claim iOS identity', () async {
    late http.Request request;
    final client = _client(
      platform: TargetPlatform.android,
      handler: (value) async {
        request = value;
        return http.Response('{"suggestions":[]}', 200);
      },
    );

    await client.autocomplete('Mexico', sessionToken: 'session');

    expect(request.headers, isNot(contains('x-ios-bundle-identifier')));
  });

  test('missing iOS bundle identifier fails closed before request', () async {
    var requestCount = 0;
    final client = _client(
      platform: TargetPlatform.iOS,
      bundleIdentifier: '  ',
      handler: (_) async {
        requestCount++;
        return http.Response('{"suggestions":[]}', 200);
      },
    );

    await expectLater(
      client.autocomplete('Mexico', sessionToken: 'session'),
      throwsA(isA<PlacesConfigurationException>()),
    );
    expect(requestCount, 0);
  });

  test(
    'autocomplete keeps its user-facing error and logs safe diagnostics',
    () async {
      const apiKey = 'AIzaTestSecretKeyThatMustNeverAppear123456';
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = previousDebugPrint);

      final client = GooglePlacesClient(
        apiKey: apiKey,
        isWeb: true,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 403,
                'status': 'PERMISSION_DENIED',
                'message': 'Request rejected for key $apiKey',
              },
            }),
            403,
          ),
        ),
      );

      await expectLater(
        client.autocomplete('Mexico City', sessionToken: 'test-session'),
        throwsA(
          isA<PlacesException>().having(
            (error) => error.message,
            'message',
            'Location suggestions are temporarily unavailable.',
          ),
        ),
      );

      final log = messages.join('\n');
      expect(log, contains('operation=autocomplete statusCode=403'));
      expect(log, contains('error.status="PERMISSION_DENIED"'));
      expect(
        log,
        contains('error.message="Request rejected for key [REDACTED]"'),
      );
      expect(log, isNot(contains(apiKey)));
      expect(log, isNot(contains('X-Goog-Api-Key')));
      expect(log, isNot(contains('X-Ios-Bundle-Identifier')));
    },
  );

  test(
    'place details logs safe diagnostics without changing its error',
    () async {
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = previousDebugPrint);
      final client = GooglePlacesClient(
        apiKey: 'test-key',
        isWeb: true,
        client: MockClient(
          (_) async => http.Response('service unavailable', 503),
        ),
      );

      await expectLater(
        client.placeDetails('place-id', sessionToken: 'test-session'),
        throwsA(
          isA<PlacesException>().having(
            (error) => error.message,
            'message',
            'Could not load that location.',
          ),
        ),
      );

      expect(
        messages.join('\n'),
        contains(
          'operation=placeDetails statusCode=503 '
          'responseBody=non-json length=19',
        ),
      );
      expect(messages.join('\n'), isNot(contains('service unavailable')));
    },
  );

  test('safe diagnostics handle malformed bodies without echoing them', () {
    const malformed = '<html>secret response content</html>';
    expect(
      safeGooglePlacesErrorSummary(malformed),
      'responseBody=non-json length=${malformed.length}',
    );
    expect(
      safeGooglePlacesErrorSummary(malformed),
      isNot(contains('secret response content')),
    );
  });
}

GooglePlacesClient _client({
  required TargetPlatform platform,
  required Future<http.Response> Function(http.Request) handler,
  bool isWeb = false,
  String bundleIdentifier = _bundleIdentifier,
}) => GooglePlacesClient(
  apiKey: _apiKey,
  client: MockClient(handler),
  isWeb: isWeb,
  targetPlatform: platform,
  iosBundleIdentifier: bundleIdentifier,
);

const _placeDetailsResponse = {
  'displayName': {'text': 'Mexico City'},
  'addressComponents': [
    {
      'longText': 'Mexico City',
      'shortText': 'CDMX',
      'types': ['locality'],
    },
    {
      'longText': 'Mexico',
      'shortText': 'MX',
      'types': ['country'],
    },
  ],
  'location': {'latitude': 19.4326, 'longitude': -99.1332},
};
