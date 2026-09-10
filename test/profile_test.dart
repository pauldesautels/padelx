import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/main.dart';
import 'package:padelx/location.dart';
import 'package:padelx/places.dart';
import 'package:padelx/social_profile.dart';

class _ProfilePlacesClient extends GooglePlacesClient {
  _ProfilePlacesClient() : super(apiKey: 'test-key');

  @override
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    required String sessionToken,
    bool citiesOnly = false,
    bool areasOnly = false,
    String countryCode = '',
    double? biasLatitude,
    double? biasLongitude,
  }) async => const [
    PlacePrediction(placeId: 'new-city', label: 'Guadalajara, Mexico'),
  ];

  @override
  Future<MatchLocation> placeDetails(
    String placeId, {
    required String sessionToken,
  }) async => const MatchLocation(
    clubName: 'Guadalajara',
    countryCode: 'MX',
    country: 'Mexico',
    region: 'Jalisco',
    city: 'Guadalajara',
    area: '',
    latitude: 20.6597,
    longitude: -103.3496,
  );
}

void main() {
  const profile = UserProfile(
    uid: 'player',
    displayName: 'Ana María With A Longer Player Name',
    level: '3.5',
    email: 'ana.private@example.com',
    socialProfile: SocialProfileData(
      preferredSide: PreferredSide.left,
      playFrequency: PlayFrequency.weekly,
      bio: 'Friendly competitive player.',
      discoverable: true,
    ),
  );

  Widget app(Widget child) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(body: child),
  );

  test('profile level is explicit without duplicating its prefix', () {
    expect(profileLevelLabel('3.5'), 'Level 3.5');
    expect(profileLevelLabel('Level 4'), 'Level 4');
    expect(profileLevelLabel(''), 'Level not set');
  });

  testWidgets('Complete and Edit Profile use the controlled numeric selector', (
    tester,
  ) async {
    for (final required in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileEditorScreen.test(
            key: UniqueKey(),
            uid: 'player',
            profile: profile,
            isRequired: required,
            onSignOut: () {},
          ),
        ),
      );
      expect(find.byKey(const Key('profile-level-field')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('profile-level-field')),
          matching: find.text('Level 3.5'),
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'Level'), findsNothing);
      await tester.tap(find.byKey(const Key('profile-level-field')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('padel-level-options')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('padel-level-option-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('padel-level-options')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('profile-level-field')),
          matching: find.text('Level 2'),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('legacy profile level is displayed safely and cannot save', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileEditorScreen.test(
          uid: 'player',
          displayName: 'Player',
          profile: UserProfile(
            uid: 'player',
            displayName: 'Player',
            level: 'Intermediate',
            email: '',
          ),
        ),
      ),
    );
    expect(
      find.textContaining('Current value "Intermediate" is legacy'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    await tester.tap(find.text('Save Profile'));
    await tester.pump();
    expect(find.text('Choose a level from 1 to 7.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Complete and Edit Profile use a controlled optional Area', (
    tester,
  ) async {
    const locatedProfile = UserProfile(
      uid: 'player',
      displayName: 'Player',
      level: '3',
      email: '',
      discoveryLocation: DiscoveryLocation(
        country: 'Mexico',
        countryCode: 'MX',
        city: 'Mexico City',
        area: 'Legacy Roma',
      ),
    );
    for (final required in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileEditorScreen.test(
            key: UniqueKey(),
            uid: 'player',
            profile: locatedProfile,
            isRequired: required,
            placesClient: _ProfilePlacesClient(),
            onSignOut: () {},
          ),
        ),
      );
      final area = find.byKey(const Key('profile-area-field'));
      await tester.scrollUntilVisible(
        area,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-city-heading')), findsOneWidget);
      expect(find.text('Change city'), findsOneWidget);
      expect(find.text('Area / Neighborhood (optional)'), findsOneWidget);
      expect(area, findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Area / Neighborhood (optional)'),
        findsNothing,
      );
      await tester.tap(area);
      await tester.pumpAndSettle();
      expect(find.text('Current area: Legacy Roma'), findsOneWidget);
      await tester.tap(find.byKey(const Key('area-selector-any')));
      await tester.pumpAndSettle();
      expect(find.text('Any area'), findsOneWidget);
    }
  });

  testWidgets('Complete Profile identifies city and Area as separate choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditorScreen.test(
          uid: 'player',
          displayName: 'Player',
          isRequired: true,
          onSignOut: () {},
          placesClient: _ProfilePlacesClient(),
        ),
      ),
    );
    final city = find.byKey(const Key('profile-city-selector'));
    await tester.scrollUntilVisible(
      city,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose city'), findsOneWidget);
    expect(find.text('Search cities only'), findsOneWidget);

    final area = find.byKey(const Key('profile-area-field'));
    await tester.scrollUntilVisible(
      area,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Area / Neighborhood (optional)'), findsOneWidget);
  });

  testWidgets('selecting a different city clears the previous Area', (
    tester,
  ) async {
    const locatedProfile = UserProfile(
      uid: 'player',
      displayName: 'Player',
      level: '3',
      email: '',
      discoveryLocation: DiscoveryLocation(
        country: 'Mexico',
        countryCode: 'MX',
        city: 'Mexico City',
        area: 'Roma',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditorScreen.test(
          uid: 'player',
          profile: locatedProfile,
          placesClient: _ProfilePlacesClient(),
        ),
      ),
    );
    final citySearch = find.byKey(const Key('places-autocomplete-field'));
    await tester.scrollUntilVisible(
      citySearch,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(citySearch, 'Guad');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guadalajara, Mexico'));
    await tester.pumpAndSettle();
    final area = find.byKey(const Key('profile-area-field'));
    await tester.scrollUntilVisible(
      area,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Any area'), findsOneWidget);
    expect(find.text('Roma'), findsNothing);
  });

  testWidgets('private profile shows identity and existing computed stats', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ProfileTab(
          profile: profile,
          uid: profile.uid,
          email: profile.email,
          onEdit: () {},
          loader: (_) async => PublicPlayerProfile(
            uid: profile.uid,
            displayName: profile.displayName,
            level: profile.level,
            matches: const [
              Match(
                id: 'one',
                title: 'Morning match',
                club: 'Roma Padel',
                level: '3.5',
                spotsLeft: 0,
                creatorUid: 'player',
                creatorEmail: 'ana.private@example.com',
                players: [],
              ),
              Match(
                id: 'two',
                title: 'Evening match',
                club: 'Centro Padel',
                level: '3.5',
                spotsLeft: 0,
                creatorUid: 'other',
                creatorEmail: '',
                players: [],
              ),
            ],
            ratings: const [
              PlayerRating(
                matchId: 'one',
                raterUid: 'a',
                ratedUid: 'player',
                rating: 4,
              ),
              PlayerRating(
                matchId: 'two',
                raterUid: 'b',
                ratedUid: 'player',
                rating: 5,
              ),
            ],
            lifetimeRatingCount: 2,
            lifetimeRatingAverage: 4.5,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(profile.displayName), findsOneWidget);
    expect(find.text(profile.email), findsOneWidget);
    expect(find.text('Level 3.5'), findsOneWidget);
    expect(find.text('4.5 ★'), findsOneWidget);
    expect(find.text('Ratings'), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.byKey(const Key('edit-profile-action')), findsOneWidget);
    expect(find.text('Left side'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Friendly competitive player.'), findsOneWidget);
    expect(find.text('Visible in Players discovery'), findsOneWidget);
  });

  testWidgets('profile remains overflow-free at 320px wide', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        ProfileTab(
          profile: profile,
          uid: profile.uid,
          email: 'an.unusually.long.private.email.address@example.com',
          onEdit: () {},
          loader: (_) async => const PublicPlayerProfile(
            uid: 'player',
            displayName: 'Ana',
            level: '3.5',
            matches: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('private-profile-overview')), findsOneWidget);
  });

  testWidgets('profile polishes loading, error, and incomplete states', (
    tester,
  ) async {
    final pending = Completer<PublicPlayerProfile>();
    await tester.pumpWidget(
      app(
        ProfileTab(
          profile: profile,
          uid: profile.uid,
          onEdit: () {},
          loader: (_) => pending.future,
        ),
      ),
    );
    expect(find.text('—'), findsNWidgets(3));

    await tester.pumpWidget(
      app(
        ProfileTab(
          profile: profile,
          uid: profile.uid,
          onEdit: () {},
          loader: (_) async => throw Exception('offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load your profile stats'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    await tester.pumpWidget(
      app(
        ProfileTab(
          uid: 'player',
          onEdit: () {},
          loader: (_) async => const PublicPlayerProfile(
            uid: 'player',
            displayName: '',
            level: '',
            matches: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Your profile needs a little more information'),
      findsOneWidget,
    );
    expect(find.text('Complete Profile'), findsOneWidget);
  });
}
