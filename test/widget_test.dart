import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:padelx/main.dart';

void main() {
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

    expect(find.text('Please enter your email address.'), findsOneWidget);
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

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
  });

  testWidgets('create match form requires all fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateMatchScreen()));

    expect(find.text('Set up a new game'), findsOneWidget);
    expect(find.text('Create Match'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilledButton, 'Create Match'));
    await tester.pump();

    expect(find.text('Please fill in all fields'), findsOneWidget);
  });

  testWidgets('my matches distinguishes organizing and joined matches', (
    WidgetTester tester,
  ) async {
    final organizingMatch = Match(
      id: 'organizing',
      title: 'Friday · 6:00 PM',
      club: 'Padel Club',
      level: 'Level 3–4',
      spotsLeft: 2,
      creatorUid: 'current-user',
      creatorEmail: 'organizer@example.com',
      players: [],
      scheduledAt: DateTime.now().add(const Duration(days: 1)),
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
      scheduledAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: [organizingMatch, joinedMatch],
            currentUid: 'current-user',
            isLoading: false,
            error: false,
          ),
        ),
      ),
    );

    expect(find.text('Organizing'), findsOneWidget);
    expect(find.text('Joined'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Friday · 6:00 PM'), findsOneWidget);
    expect(find.text('Central Padel'), findsOneWidget);
    expect(find.text('1 spot left'), findsOneWidget);
  });

  testWidgets('open matches hides past matches and orders future matches', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final matches = [
      Match(
        id: 'later',
        title: 'Later',
        club: 'Club',
        level: 'Level 3',
        spotsLeft: 2,
        creatorUid: 'one',
        creatorEmail: 'one@example.com',
        players: const [],
        scheduledAt: now.add(const Duration(days: 2)),
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
        club: 'Club',
        level: 'Level 3',
        spotsLeft: 2,
        creatorUid: 'one',
        creatorEmail: 'one@example.com',
        players: const [],
        scheduledAt: now.add(const Duration(days: 1)),
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
      tester.getTopLeft(find.text('Sooner')).dy,
      lessThan(tester.getTopLeft(find.text('Later')).dy),
    );
  });

  test('legacy matches without a timestamp remain upcoming', () {
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
    expect(find.text('You have no matches yet'), findsOneWidget);

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
    expect(find.text('Could not load your matches.'), findsOneWidget);
  });
}
