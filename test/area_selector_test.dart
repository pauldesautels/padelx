import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:padelx/area_selector.dart';
import 'package:padelx/location.dart';
import 'package:padelx/places.dart';

const location = DiscoveryLocation(
  country: 'Mexico',
  countryCode: 'MX',
  city: 'Mexico City',
  area: 'Roma',
  latitude: 19.4326,
  longitude: -99.1332,
);

GooglePlacesClient client({
  String city = 'Mexico City',
  String countryCode = 'MX',
  String area = 'Polanco',
}) => GooglePlacesClient(
  apiKey: 'test-key',
  isWeb: true,
  client: MockClient((request) async {
    if (request.method == 'POST') {
      return http.Response(
        jsonEncode({
          'suggestions': [
            {
              'placePrediction': {
                'placeId': 'area-id',
                'text': {'text': '$area, $city'},
              },
            },
          ],
        }),
        200,
      );
    }
    return http.Response(
      jsonEncode({
        'displayName': {'text': area},
        'addressComponents': [
          {
            'longText': area,
            'shortText': area,
            'types': ['neighborhood'],
          },
          {
            'longText': city,
            'shortText': city,
            'types': ['locality'],
          },
          {
            'longText': countryCode == 'MX' ? 'Mexico' : 'United States',
            'shortText': countryCode,
            'types': ['country'],
          },
        ],
      }),
      200,
    );
  }),
);

Widget app({
  String value = '',
  required ValueChanged<String> onChanged,
  GooglePlacesClient? placesClient,
}) => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: Scaffold(
    body: AreaSelectorField(
      value: value,
      location: location,
      placesClient: placesClient ?? client(),
      onChanged: onChanged,
    ),
  ),
);

Future<void> searchAndSelect(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('area-selector-field')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('places-autocomplete-field')),
    'Pola',
  );
  await tester.pump(const Duration(milliseconds: 301));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Polanco').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selects only a structured same-city Area', (tester) async {
    String? selected;
    await tester.pumpWidget(app(onChanged: (value) => selected = value));
    await searchAndSelect(tester);
    expect(selected, 'Polanco');
    expect(find.byKey(const Key('area-places-autocomplete')), findsNothing);
  });

  testWidgets('rejects another-city and another-country Areas', (tester) async {
    for (final placesClient in [
      client(city: 'Guadalajara'),
      client(countryCode: 'US'),
    ]) {
      String? selected;
      await tester.pumpWidget(
        app(placesClient: placesClient, onChanged: (value) => selected = value),
      );
      await searchAndSelect(tester);
      expect(selected, isNull);
      expect(find.text('Choose an area in Mexico City, MX.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('area-selector-cancel')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Any area clears while Back preserves the current value', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      app(value: 'Roma', onChanged: (value) => selected = value),
    );
    await tester.tap(find.byKey(const Key('area-selector-field')));
    await tester.pumpAndSettle();
    expect(find.text('Current area: Roma'), findsOneWidget);
    await tester.tap(find.byKey(const Key('area-selector-cancel')));
    await tester.pumpAndSettle();
    expect(selected, isNull);

    await tester.tap(find.byKey(const Key('area-selector-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('area-selector-any')));
    await tester.pumpAndSettle();
    expect(selected, '');
  });

  testWidgets('unconfigured Places still permits Any area', (tester) async {
    String? selected;
    await tester.pumpWidget(
      app(
        value: 'Legacy Area',
        placesClient: GooglePlacesClient(apiKey: ''),
        onChanged: (value) => selected = value,
      ),
    );
    await tester.tap(find.byKey(const Key('area-selector-field')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('area-selector-unavailable')), findsOneWidget);
    await tester.tap(find.byKey(const Key('area-selector-any')));
    await tester.pumpAndSettle();
    expect(selected, '');
  });
}
