import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/l10n/app_localizations.dart';
import 'package:padelx/location.dart';
import 'package:padelx/main.dart';

const privateMatch = Match(
  id: 'private-match', title: 'Match', club: 'Private court', level: 'Level 3',
  spotsLeft: 0, creatorUid: 'coordinator', creatorEmail: '', players: [],
  venueType: 'private_free', source: 'matchmaking',
  location: MatchLocation(clubName: 'Private court', countryCode: 'MX', country: 'Mexico',
    region: '', city: 'Mexico City', area: 'Polanco'),
);

Future<void> pumpSummary(WidgetTester tester, {String? address, Locale locale = const Locale('en')}) =>
    tester.pumpWidget(MaterialApp(locale: locale,
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: MatchDetailsSummary(match: privateMatch, completed: false,
        privateVenueAddress: address))));

void main() {
  testWidgets('private match summary remains approximate without authorized detail', (tester) async {
    await pumpSummary(tester);
    expect(find.text('Polanco, Mexico City, Mexico'), findsOneWidget);
    expect(find.byKey(const Key('private-venue-exact-location')), findsNothing);
  });

  testWidgets('authorized private detail is localized and additive', (tester) async {
    await pumpSummary(tester, address: 'Synthetic exact address', locale: const Locale('es', 'MX'));
    expect(find.text('Ubicación exacta: Synthetic exact address'), findsOneWidget);
    expect(find.text('Polanco, Mexico City, Mexico'), findsOneWidget);
  });
}
