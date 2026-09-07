import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/location.dart';
import 'package:padelx/main.dart';
import 'package:padelx/play_again.dart';
import 'package:padelx/played_with.dart';
import 'package:padelx/played_with_screen.dart';

void main() {
  const location = MatchLocation(
    clubName: 'Padel Central',
    countryCode: 'MX',
    country: 'Mexico',
    region: 'CDMX',
    city: 'Mexico City',
  );

  test('Play Again accepts only current-schema safe prefills', () {
    const safe = PlayAgainTarget(
      uid: 'b',
      displayName: 'Bea',
      location: location,
      level: 'Level 4.5',
    );
    const unsafe = PlayAgainTarget(
      uid: 'b',
      displayName: 'Bea',
      location: MatchLocation(
        clubName: 'Old Club',
        countryCode: '',
        country: '',
        region: '',
        city: '',
      ),
      level: 'Intermediate',
    );
    expect(safe.safeLocation, location);
    expect(safe.safeLevel, 'Level 4.5');
    expect(unsafe.safeLocation, isNull);
    expect(unsafe.safeLevel, isNull);
  });

  testWidgets(
    'Play Again reuses Create Match with safe fields and a fresh date',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateMatchScreen(
            playAgainTarget: PlayAgainTarget(
              uid: 'b',
              displayName: 'Bea',
              sourceMatchId: 'old-match',
              location: location,
              level: 'Level 4.5',
            ),
          ),
        ),
      );
      expect(find.text('Invite Bea after creating'), findsOneWidget);
      expect(find.text('Padel Central'), findsOneWidget);
      expect(find.text('Level 4.5'), findsOneWidget);
      final date = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Date and time'),
      );
      expect(date.controller?.text, isEmpty);
    },
  );

  testWidgets('Played With row exposes a dedicated Play Again action', (
    tester,
  ) async {
    var tapped = false;
    final player = PlayedWithPlayer(
      relationship: PlayedWithRelationship(
        otherUid: 'b',
        completedMatchCount: 1,
        lastMatchId: 'old-match',
      ),
      profile: const PlayedWithPublicProfile(
        uid: 'b',
        displayName: 'Bea',
        level: '4.5',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayedWithTile(
            player: player,
            onPlayAgain: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('play-again-b')));
    expect(tapped, isTrue);
  });

  testWidgets('Play Again notification offers View Match and Dismiss', (
    tester,
  ) async {
    var opened = false;
    var dismissed = false;
    const notification = AppNotification(
      id: 'n',
      type: AppNotificationType.playAgainInvite,
      recipientUid: 'b',
      matchId: 'new-match',
      title: 'Play again',
      message: 'You were invited to play again.',
      read: false,
      createdAt: null,
      eventId: 'b',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationCard(
            notification: notification,
            now: DateTime(2026),
            onMarkRead: (_) {},
            onOpen: (_) => opened = true,
            onDismiss: (_) => dismissed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('view-play-again-match')));
    await tester.tap(find.byKey(const Key('dismiss-play-again-invite')));
    expect(opened, isTrue);
    expect(dismissed, isTrue);
  });
}
