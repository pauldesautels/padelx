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
    const organizingMatch = Match(
      id: 'organizing',
      title: 'Friday · 6:00 PM',
      club: 'Padel Club',
      level: 'Level 3–4',
      spotsLeft: 2,
      creatorUid: 'current-user',
      creatorEmail: 'organizer@example.com',
      players: [],
    );
    const joinedMatch = Match(
      id: 'joined',
      title: 'Saturday · 10:00 AM',
      club: 'Central Padel',
      level: 'Level 2–3',
      spotsLeft: 1,
      creatorUid: 'another-user',
      creatorEmail: 'other@example.com',
      players: [MatchPlayer(uid: 'current-user', email: 'player@example.com')],
    );

    await tester.pumpWidget(
      const MaterialApp(
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
    expect(find.text('Friday · 6:00 PM'), findsOneWidget);
    expect(find.text('Central Padel'), findsOneWidget);
    expect(find.text('1 spot left'), findsOneWidget);
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
