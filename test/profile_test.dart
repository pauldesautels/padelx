import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/main.dart';
import 'package:padelx/social_profile.dart';

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
