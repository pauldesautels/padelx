import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:padelx/current_location.dart';
import 'package:padelx/location.dart';
import 'package:padelx/main.dart';
import 'package:padelx/places.dart';

void main() {
  testWidgets('auth renders official branding and login fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(loginHandler: (_, _) async {})),
    );

    expect(find.byKey(const Key('padelx-wordmark')), findsOneWidget);
    expect(find.text('Find padel matches near you.'), findsOneWidget);
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);
    expect(find.text('Log In'), findsWidgets);
  });

  testWidgets('password starts obscured and can be revealed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(loginHandler: (_, _) async {})),
    );

    TextField password = tester.widget(find.byKey(const Key('auth-password')));
    expect(password.obscureText, isTrue);
    await tester.tap(find.byKey(const Key('toggle-password-visibility')));
    await tester.pump();
    password = tester.widget(find.byKey(const Key('auth-password')));
    expect(password.obscureText, isFalse);
  });

  testWidgets('login validates friendly field-level errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(loginHandler: (_, _) async {})),
    );

    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth-email')), 'not-an-email');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('login submits once and shows loading copy', (
    WidgetTester tester,
  ) async {
    final completion = Completer<void>();
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          loginHandler: (_, _) {
            submissions++;
            return completion.future;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'player@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret12');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.text('Logging in...'), findsOneWidget);
    await tester.tap(find.byKey(const Key('auth-submit')));
    expect(submissions, 1);
    completion.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('sign up switches modes and submits existing fields', (
    WidgetTester tester,
  ) async {
    String? submittedEmail;
    String? submittedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          signUpHandler: (email, password) async {
            submittedEmail = email;
            submittedPassword = password;
          },
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('auth-switch-mode')));
    await tester.tap(find.byKey(const Key('auth-switch-mode')));
    await tester.pump();
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'new@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret12');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(submittedEmail, 'new@example.com');
    expect(submittedPassword, 'secret12');
  });

  testWidgets('auth presents Firebase errors without raw exception text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          loginHandler: (_, _) async {
            throw FirebaseAuthException(
              code: 'unexpected-code',
              message: 'sensitive backend detail',
            );
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'player@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret12');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.text('Could not log in. Please try again.'), findsOneWidget);
    expect(find.text('sensitive backend detail'), findsNothing);
  });

  testWidgets('auth fits 320px and constrains content on large screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(loginHandler: (_, _) async {})),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('auth-content'))).width, 440);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password reset sends email and shows confirmation', (
    WidgetTester tester,
  ) async {
    String? requestedEmail;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          passwordResetSender: (email) async {
            requestedEmail = email;
          },
        ),
      ),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'player@example.com',
    );
    await tester.tap(find.text('Send reset email'));
    await tester.pumpAndSettle();

    expect(requestedEmail, 'player@example.com');
    expect(
      find.text('Password reset email sent. Check your inbox.'),
      findsOneWidget,
    );
  });

  testWidgets('password reset requires an email address', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(passwordResetSender: (_) async {})),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send reset email'));
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);
  });

  testWidgets('password reset shows a clean Firebase error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          passwordResetSender: (_) async {
            throw FirebaseAuthException(code: 'invalid-email');
          },
        ),
      ),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'not-an-email',
    );
    await tester.tap(find.text('Send reset email'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
  });

  testWidgets('create match form requires all fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateMatchScreen()));

    expect(find.text('Set up your game'), findsOneWidget);
    expect(find.text('Create Match'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('create-match-submit')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('create-match-submit')).first);
    await tester.pump();

    expect(find.text('Select a padel club.'), findsWidgets);
    expect(find.byKey(const Key('date-time-error')), findsOneWidget);
    expect(find.byKey(const Key('level-error')), findsOneWidget);
  });

  testWidgets('selected club is summarized and manual details stay secondary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CreateMatchScreen(placesClient: _FakePlacesClient())),
    );

    await tester.enterText(
      find.byKey(const Key('places-autocomplete-field')),
      'Roma',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text('Roma Padel Club, Mexico City'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selected-venue-card')), findsOneWidget);
    expect(find.text('Roma Padel Club'), findsOneWidget);
    expect(find.text('Roma Norte, Mexico City, CDMX, Mexico'), findsOneWidget);
    expect(find.byKey(const Key('country-code-field')), findsNothing);

    await tester.tap(find.byKey(const Key('edit-location-details')));
    await tester.pump();
    expect(find.byKey(const Key('country-code-field')), findsOneWidget);
  });

  testWidgets(
    'create uses friendly date, explicit level, and total-player mapping',
    (WidgetTester tester) async {
      Map<String, dynamic>? saved;
      final scheduled = DateTime.now().add(const Duration(days: 2));
      await tester.pumpWidget(
        MaterialApp(
          home: CreateMatchScreen(
            initialLocation: _testLocation,
            initialScheduledAt: scheduled,
            initialLevel: 'Level 2.5',
            creator: (match) async => saved = match,
          ),
        ),
      );

      expect(find.text('Level 2.5'), findsOneWidget);
      final dateField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Date and time'),
      );
      expect(dateField.controller!.text, isNotEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const Key('create-match-submit')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('You count as one player · maximum 4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('create-match-submit')));
      await tester.pumpAndSettle();

      expect(saved?['spotsLeft'], 3);
      expect(saved?['level'], 'Level 2.5');
      expect((saved?['location'] as Map)['countryCode'], 'MX');
    },
  );

  testWidgets('create prevents double submit and shows loading', (
    WidgetTester tester,
  ) async {
    final completion = Completer<void>();
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateMatchScreen(
          initialLocation: _testLocation,
          initialScheduledAt: DateTime.now().add(const Duration(days: 2)),
          initialLevel: 'Level 2',
          creator: (_) {
            submissions++;
            return completion.future;
          },
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('create-match-submit')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('create-match-submit')));
    await tester.pump();
    expect(find.text('Creating...'), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-match-submit')));
    expect(submissions, 1);
    completion.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('create match does not overflow at 320px width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: CreateMatchScreen(initialLocation: _testLocation),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('create-match-submit')), findsOneWidget);
  });

  test('only the organizer is eligible to edit a match', () {
    final match = _match(id: 'editable', club: 'Padel Club');
    expect(canEditMatch(match, 'creator', 'other@example.com'), isTrue);
    expect(canEditMatch(match, 'another-user', 'other@example.com'), isFalse);
    expect(canEditMatch(match, null, ''), isFalse);
  });

  testWidgets('Home shows the product message and discovery location', (
    WidgetTester tester,
  ) async {
    await _pumpHome(
      tester,
      preferredLocation: const DiscoveryLocation(
        country: 'Mexico',
        countryCode: 'MX',
        city: 'Mexico City',
        area: 'Roma Norte',
      ),
    );

    expect(find.text('Find padel matches near you.'), findsOneWidget);
    expect(find.text('Roma Norte, Mexico City'), findsOneWidget);
  });

  testWidgets('Home core actions use their existing navigation callbacks', (
    WidgetTester tester,
  ) async {
    var destination = '';
    await _pumpHome(
      tester,
      onFindMatch: () => destination = 'matches',
      onCreateMatch: () => destination = 'create',
    );

    await tester.tap(find.byKey(const Key('home-find-match')));
    expect(destination, 'matches');
    await tester.tap(find.byKey(const Key('home-create-match')));
    expect(destination, 'create');
  });

  testWidgets('Home populated state shows useful match details', (
    WidgetTester tester,
  ) async {
    await _pumpHome(
      tester,
      matches: [
        _match(id: 'home', club: 'Roma Padel', level: '2', spotsLeft: 1),
      ],
    );

    expect(find.text('Roma Padel'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    expect(find.text('1 spot left'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNothing);
    expect(find.text('Unknown location'), findsNothing);
  });

  testWidgets('Home keeps the compact hierarchy free of redundant copy', (
    WidgetTester tester,
  ) async {
    await _pumpHome(tester);

    expect(find.text('FIND YOUR GAME'), findsNothing);
    expect(find.text('Upcoming games to explore'), findsNothing);
    expect(find.text('Upcoming matches'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-hero')),
        matching: find.byKey(const Key('home-create-match')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home empty state offers Create a Match', (
    WidgetTester tester,
  ) async {
    var created = false;
    await _pumpHome(tester, onCreateMatch: () => created = true);

    expect(find.text('No matches nearby yet.'), findsOneWidget);
    expect(find.text('Create a match and get a game started.'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('home-empty-state')),
        matching: find.text('Create a Match'),
      ),
    );
    expect(created, isTrue);
  });

  testWidgets('Home has polished loading and error states', (
    WidgetTester tester,
  ) async {
    await _pumpHome(tester, isLoading: true);
    expect(find.byKey(const Key('home-loading-state')), findsOneWidget);
    expect(find.text('Finding nearby matches…'), findsOneWidget);

    await _pumpHome(tester, error: true);
    expect(find.byKey(const Key('home-error-state')), findsOneWidget);
    expect(find.text('Matches are unavailable right now.'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);
  });

  testWidgets('Home does not overflow at narrow mobile width', (
    WidgetTester tester,
  ) async {
    await _pumpHome(tester, size: const Size(320, 700));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('home-find-match')), findsOneWidget);
  });

  testWidgets('edit match prepopulates current data and saves safely', (
    WidgetTester tester,
  ) async {
    final scheduledAt = DateTime(2026, 9, 12, 18, 30);
    final match = Match(
      id: 'editable',
      title: 'Saturday match',
      club: 'Roma Padel',
      level: 'Level 3',
      spotsLeft: 1,
      creatorUid: 'creator',
      creatorEmail: 'creator@example.com',
      players: const [
        MatchPlayer(uid: 'confirmed', email: 'confirmed@example.com'),
      ],
      scheduledAt: scheduledAt,
      location: const MatchLocation(
        clubName: 'Roma Padel',
        countryCode: 'MX',
        country: 'Mexico',
        region: 'CDMX',
        city: 'Mexico City',
        area: 'Roma Norte',
        placeId: 'old-place',
        latitude: 19.419,
        longitude: -99.162,
      ),
    );
    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: EditMatchScreen(
          match: match,
          saver: (update) async => saved = update,
        ),
      ),
    );

    expect(find.text('Roma Padel'), findsWidgets);
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('Mexico City'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('edit-level-field')),
      'Level 4',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-match-submit')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['level'], 'Level 4');
    expect(saved!['spotsLeft'], 1);
    expect(saved!['location'], containsPair('placeId', 'old-place'));
    expect(saved!['location'], containsPair('latitude', 19.419));
    expect(saved!['location'], containsPair('longitude', -99.162));
    expect(saved!.containsKey('players'), isFalse);
    expect(saved!.containsKey('creatorUid'), isFalse);
  });

  test('structured location and schedule edits produce discovery fields', () {
    final match = _match(id: 'location-edit', club: 'Old Club');
    final scheduledAt = DateTime(2026, 10, 2, 9);
    const location = MatchLocation(
      clubName: 'New Club',
      countryCode: 'ES',
      country: 'Spain',
      region: 'Madrid',
      city: 'Madrid',
      area: 'Centro',
      placeId: 'new-place-id',
      latitude: 40.4168,
      longitude: -3.7038,
    );
    final update = buildMatchEditUpdate(
      match: match,
      location: location,
      scheduledAt: scheduledAt,
      level: 'Level 5',
      totalCapacity: 4,
    );

    expect((update['scheduledAt'] as Timestamp).toDate(), scheduledAt);
    expect(update['club'], 'New Club');
    expect(update['level'], 'Level 5');
    expect(update['location'], containsPair('placeId', 'new-place-id'));
    expect(update['location'], containsPair('latitude', 40.4168));
    expect(update.containsKey('players'), isFalse);
  });

  test('capacity cannot be reduced below confirmed player count', () {
    final match = Match(
      id: 'full-enough',
      title: 'Match',
      club: 'Club',
      level: 'Level 3',
      spotsLeft: 1,
      creatorUid: 'creator',
      creatorEmail: 'creator@example.com',
      players: const [
        MatchPlayer(uid: 'one', email: 'one@example.com'),
        MatchPlayer(uid: 'two', email: 'two@example.com'),
      ],
      scheduledAt: DateTime(2026, 9, 1),
    );
    expect(
      () => buildMatchEditUpdate(
        match: match,
        location: const MatchLocation(
          clubName: 'Club',
          countryCode: 'MX',
          country: 'Mexico',
          region: '',
          city: 'Mexico City',
        ),
        scheduledAt: DateTime(2026, 9, 2),
        level: 'Level 3',
        totalCapacity: 2,
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  testWidgets('legacy location opens without crashing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditMatchScreen(
          match: _match(id: 'legacy', club: 'Legacy Club'),
        ),
      ),
    );
    expect(find.text('Edit Match'), findsOneWidget);
    expect(find.textContaining('Legacy location'), findsOneWidget);
  });

  testWidgets('my matches distinguishes organizing and joined matches', (
    WidgetTester tester,
  ) async {
    final now = DateTime.utc(2026, 8, 28, 12);
    final organizingMatch = Match(
      id: 'organizing',
      title: 'Friday · 6:00 PM',
      club: 'Padel Club',
      level: '2',
      spotsLeft: 2,
      creatorUid: 'current-user',
      creatorEmail: 'organizer@example.com',
      players: [],
      scheduledAt: now.add(const Duration(days: 1)),
    );
    final joinedMatch = Match(
      id: 'joined',
      title: 'Saturday · 10:00 AM',
      club: 'Central Padel',
      level: 'Level 2–3',
      spotsLeft: 1,
      creatorUid: 'another-user',
      creatorEmail: 'other@example.com',
      players: [MatchPlayer(uid: 'current-user', email: 'player@example.com')],
      scheduledAt: now.subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: [organizingMatch, joinedMatch],
            currentUid: 'current-user',
            isLoading: false,
            error: false,
            nowProvider: () => now,
          ),
        ),
      ),
    );

    expect(find.text('Organizing'), findsOneWidget);
    expect(find.text('Joined'), findsNothing);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Friday · 6:00 PM'), findsNothing);
    expect(find.text('2 spots left'), findsOneWidget);

    await tester.tap(find.text('Past'));
    await tester.pump();

    expect(find.text('Organizing'), findsNothing);
    expect(find.text('Joined'), findsOneWidget);
    expect(find.text('Central Padel'), findsOneWidget);
    expect(find.textContaining('spot'), findsNothing);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('my matches classifies and sorts around a deterministic clock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 8, 28, 12);
    final matches = [
      _match(
        id: 'future',
        club: 'Future Club',
        scheduledAt: now.add(const Duration(hours: 1)),
      ),
      _match(
        id: 'older',
        club: 'Older Past Club',
        scheduledAt: now.subtract(const Duration(days: 2)),
      ),
      _match(
        id: 'newer',
        club: 'Newer Past Club',
        scheduledAt: now.subtract(const Duration(hours: 1)),
      ),
      _match(id: 'boundary', club: 'Boundary Club', scheduledAt: now),
      const Match(
        id: 'malformed',
        title: 'Malformed',
        club: 'Malformed Club',
        level: '',
        spotsLeft: 0,
        creatorUid: 'creator',
        creatorEmail: '',
        players: [],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: matches,
            currentUid: 'creator',
            isLoading: false,
            error: false,
            nowProvider: () => now,
          ),
        ),
      ),
    );

    expect(find.text('Future Club'), findsOneWidget);
    expect(find.text('Newer Past Club'), findsNothing);
    await tester.tap(find.text('Past'));
    await tester.pump();
    expect(find.text('Future Club'), findsNothing);
    expect(find.text('Newer Past Club'), findsOneWidget);
    expect(find.text('Older Past Club'), findsOneWidget);
    expect(find.text('Boundary Club'), findsNothing);
    expect(find.text('Malformed Club'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Newer Past Club')).dy,
      lessThan(tester.getTopLeft(find.text('Older Past Club')).dy),
    );
    expect(find.text('Completed'), findsNWidgets(2));
    expect(find.textContaining('spot'), findsNothing);
  });

  testWidgets('my matches shows the no-past-matches empty state', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 28, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: [
              _match(
                id: 'future',
                club: 'Future Club',
                scheduledAt: now.add(const Duration(days: 1)),
              ),
            ],
            currentUid: 'creator',
            isLoading: false,
            error: false,
            nowProvider: () => now,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('no-past-matches')), findsNothing);
    await tester.tap(find.text('Past'));
    await tester.pump();
    expect(find.byKey(const Key('no-past-matches')), findsOneWidget);
    expect(find.text('No past matches yet.'), findsOneWidget);
  });

  testWidgets('my matches keeps upcoming order and shows date only once', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 28, 12);
    final sooner = _match(
      id: 'sooner',
      club: 'Sooner Club',
      level: '3',
      scheduledAt: DateTime.utc(2026, 8, 29, 18),
    );
    final later = _match(
      id: 'later',
      club: 'Later Club',
      scheduledAt: DateTime.utc(2026, 8, 30, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: [later, sooner],
            currentUid: 'creator',
            isLoading: false,
            error: false,
            nowProvider: () => now,
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Sooner Club')).dy,
      lessThan(tester.getTopLeft(find.text('Later Club')).dy),
    );
    expect(find.text('Saturday, August 29 · 6:00 PM'), findsOneWidget);
    expect(find.text('Level 3'), findsWidgets);
  });

  testWidgets('my matches gracefully omits missing legacy location', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 28, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: [
              _match(
                id: 'legacy-location',
                club: 'Legacy Club',
                scheduledAt: now.add(const Duration(days: 1)),
              ),
            ],
            currentUid: 'creator',
            isLoading: false,
            error: false,
            nowProvider: () => now,
          ),
        ),
      ),
    );

    expect(find.text('Legacy Club'), findsOneWidget);
    expect(find.text('Legacy location'), findsNothing);
  });

  testWidgets('my matches empty actions and 320px layout do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var findTapped = false;
    var createTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: const [],
            currentUid: 'current-user',
            onFindMatch: () => findTapped = true,
            onCreateMatch: () => createTapped = true,
            isLoading: false,
            error: false,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('find-match-empty-action')));
    await tester.tap(find.byKey(const Key('create-match-empty-action')));
    expect(findTapped, isTrue);
    expect(createTapped, isTrue);
    await tester.tap(find.text('Past'));
    await tester.pump();
    expect(find.byKey(const Key('no-past-matches')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'my matches membership includes organizer and confirmed player only',
    () {
      final match = Match(
        id: 'shared',
        title: 'Shared match',
        club: 'Shared Club',
        level: 'Level 3',
        spotsLeft: 1,
        creatorUid: 'creator',
        creatorEmail: 'creator@example.com',
        players: const [MatchPlayer(uid: 'confirmed', email: 'p@example.com')],
        scheduledAt: DateTime.utc(2026, 8, 1),
      );
      expect(matchesForUser([match], 'creator', ''), [match]);
      expect(matchesForUser([match], 'confirmed', ''), [match]);
      expect(matchesForUser([match], 'unrelated', ''), isEmpty);
    },
  );

  test('completed matches expose no mutation actions', () {
    final now = DateTime.utc(2026, 8, 28, 12);
    expect(
      matchAllowsChanges(
        _match(
          id: 'completed',
          club: 'Past Club',
          scheduledAt: now.subtract(const Duration(minutes: 1)),
        ),
        now,
      ),
      isFalse,
    );
    expect(
      matchAllowsChanges(
        _match(
          id: 'future',
          club: 'Future Club',
          scheduledAt: now.add(const Duration(minutes: 1)),
        ),
        now,
      ),
      isTrue,
    );
  });

  testWidgets('open matches hides past matches and orders future matches', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final soonerDate = now.add(const Duration(days: 1));
    final laterDate = now.add(const Duration(days: 2));
    final matches = [
      Match(
        id: 'later',
        title: 'Later',
        club: 'Later Club',
        level: 'Level 3',
        spotsLeft: 2,
        creatorUid: 'one',
        creatorEmail: 'one@example.com',
        players: const [],
        scheduledAt: laterDate,
      ),
      Match(
        id: 'past',
        title: 'Past match',
        club: 'Club',
        level: 'Level 3',
        spotsLeft: 2,
        creatorUid: 'one',
        creatorEmail: 'one@example.com',
        players: const [],
        scheduledAt: now.subtract(const Duration(days: 1)),
      ),
      Match(
        id: 'sooner',
        title: 'Sooner',
        club: 'Sooner Club',
        level: 'Level 3',
        spotsLeft: 2,
        creatorUid: 'one',
        creatorEmail: 'one@example.com',
        players: const [],
        scheduledAt: soonerDate,
      ),
    ];
    final openMatches = sortedMatches(
      matches.where((match) => !isPastMatch(match, now)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesTab(
            matches: openMatches,
            isLoading: false,
            error: false,
          ),
        ),
      ),
    );

    expect(find.text('Past match'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Sooner Club')).dy,
      lessThan(tester.getTopLeft(find.text('Later Club')).dy),
    );
  });

  testWidgets('open matches search filters by club or location immediately', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [
      _match(id: 'one', club: 'Roma Padel Center'),
      _match(id: 'two', club: 'Polanco Courts'),
    ]);

    await tester.enterText(find.byKey(const Key('match-search-field')), 'roma');
    await tester.pump();

    expect(find.text('Roma Padel Center'), findsOneWidget);
    expect(find.text('Polanco Courts'), findsNothing);
  });

  testWidgets('open matches date filters handle today tomorrow and this week', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final today = now.add(const Duration(minutes: 1));
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 12);
    final nextWeek = DateTime(
      now.year,
      now.month,
      now.day + (8 - now.weekday),
      12,
    );
    await _pumpMatches(tester, [
      _match(id: 'today', club: 'Today Club', scheduledAt: today),
      _match(id: 'tomorrow', club: 'Tomorrow Club', scheduledAt: tomorrow),
      _match(id: 'next-week', club: 'Next Week Club', scheduledAt: nextWeek),
    ]);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Today'));
    await tester.pump();
    expect(find.text('Today Club'), findsOneWidget);
    expect(find.text('Tomorrow Club'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow'));
    await tester.pump();
    expect(find.text('Tomorrow Club'), findsOneWidget);
    expect(find.text('Today Club'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'This Week'));
    await tester.pump();
    expect(find.text('Today Club'), findsOneWidget);
    expect(find.text('Next Week Club'), findsNothing);
  });

  testWidgets('open matches filters by player level', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [
      _match(id: 'beginner', club: 'Beginner Club', level: 'Level 1'),
      _match(id: 'advanced', club: 'Advanced Club', level: 'Level 4'),
    ]);

    await tester.tap(find.byKey(const Key('level-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 4').last);
    await tester.pumpAndSettle();

    expect(find.text('Advanced Club'), findsOneWidget);
    expect(find.text('Beginner Club'), findsNothing);
  });

  testWidgets('open matches can show only matches with available spots', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [
      _match(id: 'open', club: 'Open Club', spotsLeft: 1),
      _match(id: 'full', club: 'Full Club', spotsLeft: 0),
    ]);

    await tester.tap(find.byKey(const Key('available-spots-filter')));
    await tester.pump();

    expect(find.text('Open Club'), findsOneWidget);
    expect(find.text('Full Club'), findsNothing);
  });

  testWidgets('open matches combines filters and clear restores all matches', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [
      _match(id: 'target', club: 'Roma Padel', level: 'Level 3', spotsLeft: 2),
      _match(
        id: 'wrong-level',
        club: 'Roma Courts',
        level: 'Level 2',
        spotsLeft: 2,
      ),
      _match(id: 'full', club: 'Roma Arena', level: 'Level 3', spotsLeft: 0),
    ]);

    await tester.enterText(find.byKey(const Key('match-search-field')), 'roma');
    await tester.tap(find.byKey(const Key('level-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('available-spots-filter')));
    await tester.pump();

    expect(find.text('Roma Padel'), findsOneWidget);
    expect(find.text('Roma Courts'), findsNothing);
    expect(find.text('Roma Arena'), findsNothing);

    await tester.tap(find.byKey(const Key('clear-match-filters')));
    await tester.pump();
    expect(find.text('Roma Padel'), findsOneWidget);
    expect(find.text('Roma Courts'), findsOneWidget);
    expect(find.text('Roma Arena'), findsOneWidget);
  });

  testWidgets('open matches shows empty results with a reset option', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [_match(id: 'one', club: 'Roma Padel')]);

    await tester.enterText(
      find.byKey(const Key('match-search-field')),
      'missing',
    );
    await tester.pump();
    expect(find.text('No matches match your filters'), findsOneWidget);
    expect(find.text('Clear filters'), findsWidgets);

    await tester.tap(find.text('Clear filters').last);
    await tester.pump();
    expect(find.text('Roma Padel'), findsOneWidget);
    expect(find.text('No matches match your filters'), findsNothing);
  });

  testWidgets('open matches separates discovery location from text search', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [_match(id: 'one', club: 'Roma Padel')]);

    expect(find.byKey(const Key('matches-location-controls')), findsOneWidget);
    expect(find.text('Find matches near'), findsOneWidget);
    expect(find.byKey(const Key('use-current-location')), findsOneWidget);
    expect(find.text('Filter matches'), findsOneWidget);
    expect(find.byKey(const Key('match-search-field')), findsOneWidget);
  });

  testWidgets('open match cards use one date headline and explicit level', (
    WidgetTester tester,
  ) async {
    final scheduledAt = DateTime(2030, 9, 12, 18, 30);
    const dateLabel = 'Thursday, September 12 · 6:30 PM';
    await _pumpMatches(tester, [
      Match(
        id: 'legacy',
        title: dateLabel,
        club: 'Legacy Club',
        level: '2',
        spotsLeft: 1,
        creatorUid: 'current-user',
        creatorEmail: 'organizer@example.com',
        players: const [],
        scheduledAt: scheduledAt,
      ),
    ], currentUid: 'current-user');

    expect(find.text(dateLabel), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('1 spot left'), findsOneWidget);
    expect(find.text('Organizer'), findsOneWidget);
    expect(find.text('Unknown location'), findsNothing);
  });

  testWidgets('open matches distinguishes global and filter empty states', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, const []);
    expect(find.text('No open matches yet'), findsOneWidget);

    await _pumpMatches(tester, [_match(id: 'one', club: 'Roma Padel')]);
    await tester.enterText(find.byKey(const Key('match-search-field')), 'none');
    await tester.pump();
    expect(find.text('No matches match your filters'), findsOneWidget);
  });

  testWidgets('open matches does not overflow at 320px width', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [
      _match(id: 'one', club: 'A very long padel club name'),
    ], size: const Size(320, 700));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('matches-scroll-view')), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'This Week'), findsOneWidget);
  });

  testWidgets('current location applies the default 25 km radius', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now().add(const Duration(days: 1));
    Match locatedMatch(String id, double longitude) => Match(
      id: id,
      title: id,
      club: '$id club',
      level: 'Level 3',
      spotsLeft: 2,
      creatorUid: 'creator',
      creatorEmail: 'creator@example.com',
      players: const [],
      scheduledAt: now,
      location: MatchLocation(
        clubName: '$id club',
        countryCode: 'MX',
        country: 'Mexico',
        region: '',
        city: 'Test City',
        latitude: 0,
        longitude: longitude,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesTab(
            matches: [locatedMatch('near', 0.1), locatedMatch('far', 0.3)],
            isLoading: false,
            error: false,
            currentLocationProvider: const _FakeCurrentLocationProvider(
              coordinates: CurrentCoordinates(latitude: 0, longitude: 0),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('use-current-location')));
    await tester.pumpAndSettle();

    expect(find.text('Current location · 25 km radius'), findsOneWidget);
    expect(find.text('near club'), findsOneWidget);
    expect(find.text('far club'), findsNothing);
    expect(find.textContaining('km away'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '25 km'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '50 km'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '100 km'), findsOneWidget);
  });

  testWidgets('location denial keeps matches and manual discovery available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesTab(
            matches: [_match(id: 'one', club: 'Manual Search Club')],
            isLoading: false,
            error: false,
            currentLocationProvider: const _FakeCurrentLocationProvider(
              error: CurrentLocationError.permissionDenied,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('use-current-location')));
    await tester.pumpAndSettle();

    expect(find.text('Manual Search Club'), findsOneWidget);
    expect(find.byKey(const Key('use-current-location')), findsOneWidget);
    expect(find.byKey(const Key('current-location-error')), findsOneWidget);
    expect(find.textContaining('search for a location manually'), findsWidgets);
  });

  test('legacy matches without a timestamp fail classification gracefully', () {
    const legacyMatch = Match(
      id: 'legacy',
      title: 'Friday · 6:00 PM',
      club: 'Club',
      level: 'Level 3',
      spotsLeft: 2,
      creatorUid: 'one',
      creatorEmail: 'one@example.com',
      players: [],
    );

    expect(isPastMatch(legacyMatch, DateTime.now()), isFalse);
    expect(isUpcomingMatch(legacyMatch, DateTime.now()), isFalse);
  });

  testWidgets('my matches shows empty and error states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: [],
            currentUid: 'current-user',
            isLoading: false,
            error: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('no-upcoming-matches')), findsOneWidget);
    expect(find.text('No upcoming matches.'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: [],
            currentUid: 'current-user',
            isLoading: false,
            error: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('my-matches-error-state')), findsOneWidget);
    expect(
      find.text('Your matches are unavailable right now.'),
      findsOneWidget,
    );
  });

  test(
    'requesting to join creates a pending request without adding a player',
    () {
      const request = JoinRequest(
        userId: 'player',
        displayName: 'Ana',
        level: 'Level 3',
        email: 'ana@example.com',
        status: 'pending',
      );
      validateJoinRequest({'players': <Map<String, dynamic>>[]}, null, request);

      final document = request.toMap();
      expect(document['userId'], 'player');
      expect(document['status'], 'pending');
    },
  );

  test('a duplicate pending join request is rejected', () {
    expect(
      () => validateJoinRequest(
        {'players': <Map<String, dynamic>>[]},
        {'userId': 'player', 'status': 'pending'},
        const JoinRequest(
          userId: 'player',
          displayName: 'Ana',
          level: 'Level 3',
          email: 'ana@example.com',
          status: 'pending',
        ),
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  test('an approved requester cannot submit another request', () {
    expect(
      () => validateJoinRequest(
        {'players': <Map<String, dynamic>>[]},
        {'userId': 'player', 'status': 'approved'},
        const JoinRequest(
          userId: 'player',
          displayName: 'Ana',
          level: 'Level 3',
          email: 'ana@example.com',
          status: 'pending',
        ),
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  test('legacy player maps using userId are recognized as confirmed', () {
    final player = MatchPlayer.fromMap({
      'userId': 'legacy-player',
      'email': 'legacy@example.com',
    });

    expect(player.uid, 'legacy-player');
    expect(
      () => validateJoinRequest(
        {
          'players': [
            {'userId': 'legacy-player', 'email': 'legacy@example.com'},
          ],
        },
        null,
        const JoinRequest(
          userId: 'legacy-player',
          displayName: 'Legacy Player',
          level: 'Level 2',
          email: 'legacy@example.com',
          status: 'pending',
        ),
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  test('legacy createdBy fields resolve to the organizer identity', () {
    final data = {
      'createdBy': 'rwW6TOBywxYII1Zeee7Bc1cTzzC3',
      'createdByEmail': 'pauldesautels@hotmail.com',
    };

    expect(matchCreatorUid(data), 'rwW6TOBywxYII1Zeee7Bc1cTzzC3');
    expect(matchCreatorEmail(data), 'pauldesautels@hotmail.com');
    expect(
      isOrganizerIdentity(
        data,
        'rwW6TOBywxYII1Zeee7Bc1cTzzC3',
        'pauldesautels@hotmail.com',
      ),
      isTrue,
    );
    expect(
      isOrganizerIdentity(data, 'different-user', 'other@example.com'),
      isFalse,
    );
  });

  test('join request creates one deterministic organizer notification', () {
    final data = buildJoinRequestNotification(
      recipientUid: 'organizer',
      matchId: 'match-1',
      matchClubName: 'Roma Padel',
      eventId: 'event-1',
      actorUid: 'player',
      actorDisplayName: 'Ana',
    );

    expect(data['recipientUid'], 'organizer');
    expect(data['message'], 'Ana requested to join your match at Roma Padel.');
    expect(data['isRead'], isFalse);
    expect(data['createdAt'], isA<FieldValue>());
    expect(data['actorUid'], isNot(data['recipientUid']));
    expect(
      notificationDocumentId(
        AppNotificationType.joinRequest,
        'match-1',
        'event-1',
      ),
      notificationDocumentId(
        AppNotificationType.joinRequest,
        'match-1',
        'event-1',
      ),
    );
  });

  test('approval and decline notifications contain the match club', () {
    final approved = buildReviewNotification(
      approve: true,
      recipientUid: 'player',
      matchId: 'match-1',
      club: 'Roma Padel',
      eventId: 'event-1',
      actorUid: 'organizer',
      actorDisplayName: 'Paul',
    );
    final declined = buildReviewNotification(
      approve: false,
      recipientUid: 'player',
      matchId: 'match-1',
      club: 'Roma Padel',
      eventId: 'event-1',
      actorUid: 'organizer',
      actorDisplayName: 'Paul',
    );

    expect(
      approved['message'],
      'Your request to join the match at Roma Padel was approved.',
    );
    expect(
      declined['message'],
      'Your request to join the match at Roma Padel was declined.',
    );
    expect(approved['actorUid'], isNot(approved['recipientUid']));
    expect(declined['actorUid'], isNot(declined['recipientUid']));
  });

  test('notification ownership denies another user', () {
    expect(canReadNotification('recipient', 'recipient'), isTrue);
    expect(canReadNotification('another-user', 'recipient'), isFalse);
    expect(canReadNotification('', 'recipient'), isFalse);
  });

  test('unread notification count ignores read items', () {
    expect(
      unreadNotificationCount([
        _notification(id: 'one'),
        _notification(id: 'two', read: true),
        _notification(id: 'three'),
      ]),
      2,
    );
  });

  testWidgets('notifications show empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: const [],
            isLoading: false,
            error: false,
            onMarkRead: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('unread notification can be marked read', (
    WidgetTester tester,
  ) async {
    AppNotification? markedRead;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: [_notification(id: 'one')],
            isLoading: false,
            error: false,
            onMarkRead: (notification) => markedRead = notification,
            onOpen: (_) {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Mark as read'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark as read'));
    expect(markedRead?.id, 'one');
  });

  testWidgets('notification badge displays unread count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NotificationBadge(count: 3))),
    );

    expect(find.text('3'), findsOneWidget);
  });

  test('a declined player can submit a new pending request', () {
    expect(
      () => validateJoinRequest(
        {'players': <Map<String, dynamic>>[]},
        {'userId': 'player', 'status': 'declined'},
        const JoinRequest(
          userId: 'player',
          displayName: 'Ana',
          level: 'Level 3',
          email: 'ana@example.com',
          status: 'pending',
        ),
      ),
      returnsNormally,
    );
  });

  test('match participation state restores persisted request status', () {
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: true,
        requestStatus: 'pending',
      ),
      MatchParticipationState.confirmed,
    );
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: false,
        requestStatus: 'pending',
      ),
      MatchParticipationState.pending,
    );
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: false,
        requestStatus: 'declined',
      ),
      MatchParticipationState.available,
    );
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: false,
      ),
      MatchParticipationState.available,
    );
    expect(
      resolveMatchParticipationState(
        isOrganizer: true,
        isConfirmedPlayer: false,
        requestStatus: 'pending',
      ),
      MatchParticipationState.organizer,
    );
  });

  test(
    'leave refresh makes live membership authoritative for button state',
    () {
      final beforeLeave = resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: true,
        requestStatus: 'approved',
      );
      final afterLeave = resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: false,
        requestStatus: 'declined',
      );

      expect(
        matchParticipationButtonLabel(beforeLeave, spotsLeft: 1),
        'Leave Match',
      );
      expect(
        matchParticipationButtonLabel(afterLeave, spotsLeft: 2),
        'Request to Join',
      );
    },
  );

  test('approved request alone does not create stale confirmed membership', () {
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: false,
        requestStatus: 'approved',
      ),
      MatchParticipationState.available,
    );
  });

  test('pending request and organizer button behavior remain unchanged', () {
    expect(
      matchParticipationButtonLabel(
        resolveMatchParticipationState(
          isOrganizer: false,
          isConfirmedPlayer: false,
          requestStatus: 'pending',
        ),
        spotsLeft: 2,
      ),
      'Request Pending',
    );
    expect(
      matchParticipationButtonLabel(
        resolveMatchParticipationState(
          isOrganizer: true,
          isConfirmedPlayer: false,
          requestStatus: 'pending',
        ),
        spotsLeft: 2,
      ),
      'Cancel Match',
    );
  });

  testWidgets('organizer sees pending requests and can approve or decline', (
    WidgetTester tester,
  ) async {
    const request = JoinRequest(
      userId: 'player',
      displayName: 'Ana Player',
      level: 'Level 3',
      email: 'ana@example.com',
      status: 'pending',
    );
    bool approved = false;
    bool declined = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JoinRequestsSection(
            requests: const [request],
            onApprove: (_) => approved = true,
            onDecline: (_) => declined = true,
          ),
        ),
      ),
    );

    expect(find.text('Join Requests'), findsOneWidget);
    expect(find.text('Ana Player'), findsOneWidget);
    expect(find.text('Level 3'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    expect(approved, isTrue);
    await tester.tap(find.text('Decline'));
    expect(declined, isTrue);
  });

  testWidgets(
    'organizer request section shows loading empty and error states',
    (WidgetTester tester) async {
      Widget section({bool loading = false, String? errorMessage}) {
        return MaterialApp(
          home: Scaffold(
            body: JoinRequestsSection(
              requests: const [],
              loading: loading,
              errorMessage: errorMessage,
              onApprove: (_) {},
              onDecline: (_) {},
            ),
          ),
        );
      }

      await tester.pumpWidget(section(loading: true));
      expect(find.text('Loading join requests...'), findsOneWidget);
      expect(find.text('No pending requests'), findsNothing);

      await tester.pumpWidget(section());
      expect(find.text('No pending requests'), findsOneWidget);

      await tester.pumpWidget(
        section(errorMessage: 'Permission denied while loading join requests.'),
      );
      expect(
        find.text('Permission denied while loading join requests.'),
        findsOneWidget,
      );
      expect(find.text('No pending requests'), findsNothing);
    },
  );

  testWidgets(
    'match summary shows date once, explicit level, and no location',
    (WidgetTester tester) async {
      final match = Match(
        id: 'summary',
        title: 'Legacy title',
        club: 'Roma Padel',
        level: '2',
        spotsLeft: 1,
        creatorUid: 'organizer',
        creatorEmail: '',
        players: const [],
        scheduledAt: DateTime(2026, 9, 2, 18, 30),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: MatchDetailsSummary(match: match, completed: false),
          ),
        ),
      );

      expect(find.byKey(const Key('match-details-date-time')), findsOneWidget);
      expect(find.text('Wednesday, September 2 · 6:30 PM'), findsOneWidget);
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text('1 spot left'), findsOneWidget);
      expect(find.text('Legacy title'), findsNothing);
    },
  );

  testWidgets('join request controls fit a 320px mobile layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: JoinRequestsSection(
            requests: const [
              JoinRequest(
                userId: 'player',
                displayName: 'A player with a long display name',
                email: '',
                level: '2',
                status: 'pending',
              ),
            ],
            onApprove: (_) {},
            onDecline: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  test('approving adds one confirmed player and updates capacity', () {
    final update = buildReviewRequestUpdate(
      {'spotsLeft': 2, 'players': <Map<String, dynamic>>[]},
      {
        'userId': 'player',
        'displayName': 'Ana',
        'level': 'Level 3',
        'email': 'ana@example.com',
        'status': 'pending',
      },
    );

    expect((update['players'] as List), hasLength(1));
    expect(update['spotsLeft'], 1);
    expect(buildRequestStatusUpdate({'status': 'pending'}, approve: true), {
      'status': 'approved',
    });
  });

  test(
    'approval normalizes a legacy match without players and string spots',
    () {
      final update = buildReviewRequestUpdate(
        {'spotsLeft': '2 spots left'},
        {
          'userId': 'player',
          'displayName': 'Ana',
          'level': 'Level 3',
          'email': 'ana@example.com',
          'status': 'pending',
        },
      );

      expect(update['spotsLeft'], 1);
      expect((update['players'] as List).single['uid'], 'player');
    },
  );

  test(
    'approval preserves legacy organizer fields and appends a clean player',
    () {
      final joinedAt = Timestamp.fromDate(DateTime.utc(2026, 5, 8));
      final update = buildReviewRequestUpdate(
        {
          'spotsLeft': 2,
          'players': [
            {
              'uid': 'organizer',
              'email': 'organizer@example.com',
              'role': 'Player',
              'joinedAt': joinedAt,
              'legacyMetadata': {
                'clubs': ['Polanco'],
              },
            },
          ],
        },
        {
          'userId': 'requester',
          'displayName': 'Paul2',
          'level': '2',
          'email': 'requester@example.com',
          'status': 'pending',
        },
      );

      final players = update['players'] as List;
      expect(players.first['role'], 'Player');
      expect(players.first['joinedAt'], same(joinedAt));
      expect(players.first['legacyMetadata'], {
        'clubs': ['Polanco'],
      });
      expect(players.first, isA<Map<String, dynamic>>());
      expect(players.first['legacyMetadata'], isA<Map<String, dynamic>>());
      expect(
        (players.first['legacyMetadata'] as Map)['clubs'],
        isA<List<dynamic>>(),
      );
      expect((players.last as Map).keys, {
        'uid',
        'email',
        'displayName',
        'level',
      });
      expect(update['spotsLeft'], 1);
    },
  );

  test('legacy player normalization rejects non-Firestore values', () {
    expect(
      () => normalizeLegacyPlayers([
        {'uid': 'organizer', 'unsupported': Object()},
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('declining changes status without adding a confirmed player', () {
    final update = buildRequestStatusUpdate({
      'userId': 'player',
      'status': 'pending',
    }, approve: false);

    expect(update, {'status': 'declined'});
  });

  test('approval is rejected when the four-person match is full', () {
    expect(
      () => buildReviewRequestUpdate(
        {
          'spotsLeft': 1,
          'players': [
            {'uid': 'one'},
            {'uid': 'two'},
            {'uid': 'three'},
          ],
        },
        {'userId': 'four', 'status': 'pending'},
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  test('approval cannot create duplicate participation', () {
    expect(
      () => buildReviewRequestUpdate(
        {
          'spotsLeft': 2,
          'players': [
            {'uid': 'player'},
          ],
        },
        {'userId': 'player', 'status': 'pending'},
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  testWidgets('pending requests are separate from joined matches', (
    WidgetTester tester,
  ) async {
    final pending = _match(id: 'pending', club: 'Pending Club');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: const [],
            pendingMatches: [pending],
            currentUid: 'player',
            isLoading: false,
            error: false,
          ),
        ),
      ),
    );

    expect(find.text('Pending Requests'), findsOneWidget);
    expect(find.text('Request Pending'), findsOneWidget);
    expect(find.text('Joined'), findsNothing);
  });

  test('match participation supports organizer and legacy player shapes', () {
    expect(
      matchIncludesPlayer({'creatorUid': 'organizer'}, 'organizer'),
      isTrue,
    );
    expect(
      matchIncludesPlayer({'createdBy': 'legacy-owner'}, 'legacy-owner'),
      isTrue,
    );
    expect(
      matchIncludesPlayer({
        'players': [
          {'userId': 'legacy-player'},
          {'uid': 'current-player'},
          'malformed',
        ],
      }, 'legacy-player'),
      isTrue,
    );
    expect(matchIncludesPlayer({'players': 'not-a-list'}, 'player'), isFalse);
    expect(matchIncludesPlayer(const {}, ''), isFalse);
    expect(matchPlayersFromValue('not-a-list'), isEmpty);
    expect(
      matchPlayersFromValue([
        {'userId': 'legacy-player'},
        null,
      ]).single.uid,
      'legacy-player',
    );
  });

  test(
    'recent history is newest first, limited, and tolerates missing dates',
    () {
      final matches = [
        _match(id: 'old', club: 'Old', scheduledAt: DateTime(2026, 1, 1)),
        _match(id: 'new', club: 'New', scheduledAt: DateTime(2026, 8, 1)),
        const Match(
          id: 'legacy',
          title: '',
          club: '',
          level: '',
          spotsLeft: 0,
          creatorUid: 'creator',
          creatorEmail: '',
          players: [],
        ),
      ];

      expect(recentPlayerMatches(matches, limit: 2).map((match) => match.id), [
        'new',
        'old',
      ]);
    },
  );

  testWidgets('public profile shows only public fields and computed history', (
    WidgetTester tester,
  ) async {
    final matches = [
      _match(id: 'one', club: 'Roma Padel'),
      _match(id: 'two', club: 'Centro Padel'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerProfileScreen(
          uid: 'player',
          fallbackName: 'private@example.com',
          loader: (_) async => PublicPlayerProfile(
            uid: 'player',
            displayName: 'Ana',
            level: 'Level 4',
            matches: matches,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Player Profile'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Level 4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Roma Padel'), findsOneWidget);
    expect(find.text('private@example.com'), findsNothing);
  });

  testWidgets('even a malformed player row opens the public profile screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePlayerTile(
            uid: '',
            fallbackName: 'Legacy player',
            fallbackLevel: '',
            role: 'Organizer',
            profileLoader: (_) async => const PublicPlayerProfile(
              uid: '',
              displayName: '',
              level: '',
              matches: [],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Legacy player'));
    await tester.pumpAndSettle();
    expect(find.text('Player Profile'), findsOneWidget);
    expect(find.text('Legacy player'), findsOneWidget);
  });
}

const _testLocation = MatchLocation(
  clubName: 'Roma Padel Club',
  countryCode: 'MX',
  country: 'Mexico',
  region: 'CDMX',
  city: 'Mexico City',
  area: 'Roma Norte',
  placeId: 'roma-padel',
  latitude: 19.42,
  longitude: -99.16,
);

class _FakePlacesClient extends GooglePlacesClient {
  _FakePlacesClient() : super(apiKey: 'test-key');

  @override
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    required String sessionToken,
    bool citiesOnly = false,
  }) async => const [
    PlacePrediction(
      placeId: 'roma-padel',
      label: 'Roma Padel Club, Mexico City',
    ),
  ];

  @override
  Future<MatchLocation> placeDetails(
    String placeId, {
    required String sessionToken,
  }) async => _testLocation;
}

Match _match({
  required String id,
  required String club,
  String level = 'Level 3',
  int spotsLeft = 2,
  DateTime? scheduledAt,
}) {
  return Match(
    id: id,
    title: 'Match $id',
    club: club,
    level: level,
    spotsLeft: spotsLeft,
    creatorUid: 'creator',
    creatorEmail: 'creator@example.com',
    players: const [],
    scheduledAt: scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
  );
}

Future<void> _pumpMatches(
  WidgetTester tester,
  List<Match> matches, {
  Size size = const Size(1200, 1800),
  String currentUid = '',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MatchesTab(
          matches: matches,
          isLoading: false,
          error: false,
          currentUid: currentUid,
        ),
      ),
    ),
  );
}

Future<void> _pumpHome(
  WidgetTester tester, {
  List<Match> matches = const [],
  DiscoveryLocation? preferredLocation,
  VoidCallback? onFindMatch,
  VoidCallback? onCreateMatch,
  bool isLoading = false,
  bool error = false,
  Size size = const Size(430, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: HomeTab(
          onFindMatch: onFindMatch ?? () {},
          onCreateMatch: onCreateMatch ?? () {},
          matches: matches,
          preferredLocation: preferredLocation,
          isLoading: isLoading,
          error: error,
        ),
      ),
    ),
  );
}

AppNotification _notification({required String id, bool read = false}) {
  return AppNotification(
    id: id,
    type: AppNotificationType.joinRequest,
    recipientUid: 'recipient',
    matchId: 'match-1',
    title: 'New join request',
    message: 'Ana requested to join your match.',
    read: read,
    createdAt: DateTime.utc(2026, 8, 26),
    eventId: 'event-$id',
    actorUid: 'player',
    actorDisplayName: 'Ana',
  );
}

class _FakeCurrentLocationProvider implements CurrentLocationProvider {
  final CurrentCoordinates? coordinates;
  final CurrentLocationError? error;

  const _FakeCurrentLocationProvider({this.coordinates, this.error});

  @override
  Future<CurrentCoordinates> getCurrentLocation() async {
    if (error != null) throw CurrentLocationException(error!);
    return coordinates!;
  }
}
