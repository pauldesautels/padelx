import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/main.dart';
import 'package:padelx/profile_avatar.dart';

void main() {
  final completedMatch = Match(
    id: 'completed',
    title: 'Completed match',
    club: 'Roma Padel',
    level: 'Level 3',
    spotsLeft: 1,
    creatorUid: 'organizer',
    creatorEmail: 'organizer@example.com',
    players: const [
      MatchPlayer(uid: 'rater', email: 'rater@example.com'),
      MatchPlayer(uid: 'rated', email: 'rated@example.com'),
    ],
    scheduledAt: DateTime.utc(2026, 8, 1),
  );

  bool eligible({
    Match? match,
    String raterUid = 'rater',
    String ratedUid = 'rated',
    PlayerRating? existing,
  }) => canRatePlayerForMatch(
    match: match ?? completedMatch,
    raterUid: raterUid,
    raterEmail: '$raterUid@example.com',
    ratedUid: ratedUid,
    ratedEmail: '$ratedUid@example.com',
    now: DateTime.utc(2026, 8, 2),
    existingRating: existing,
  );

  test('eligible confirmed participants can rate after their shared match', () {
    expect(eligible(), isTrue);
    expect(eligible(raterUid: 'organizer'), isTrue);
  });

  test('self-rating is blocked', () {
    expect(eligible(raterUid: 'rated', ratedUid: 'rated'), isFalse);
  });

  test('non-participant rating is blocked', () {
    expect(eligible(raterUid: 'stranger'), isFalse);
  });

  test('rating before match completion is blocked', () {
    final future = Match(
      id: 'future',
      title: 'Future match',
      club: 'Roma Padel',
      level: 'Level 3',
      spotsLeft: 1,
      creatorUid: 'organizer',
      creatorEmail: 'organizer@example.com',
      players: completedMatch.players,
      scheduledAt: DateTime.utc(2026, 8, 3),
    );
    expect(eligible(match: future), isFalse);
  });

  test('existing per-match rating blocks a duplicate', () {
    expect(
      eligible(
        existing: const PlayerRating(
          matchId: 'completed',
          raterUid: 'rater',
          ratedUid: 'rated',
          rating: 4,
        ),
      ),
      isFalse,
    );
  });

  test('only integer values from 1 through 5 are accepted', () {
    expect(isValidRatingValue(0), isFalse);
    expect(isValidRatingValue(1), isTrue);
    expect(isValidRatingValue(5), isTrue);
    expect(isValidRatingValue(6), isFalse);
  });

  test('rating average and count are calculated from immutable records', () {
    final summary = RatingSummary.fromRatings(const [
      PlayerRating(matchId: 'one', raterUid: 'a', ratedUid: 'rated', rating: 4),
      PlayerRating(matchId: 'two', raterUid: 'b', ratedUid: 'rated', rating: 5),
      PlayerRating(
        matchId: 'three',
        raterUid: 'c',
        ratedUid: 'rated',
        rating: 5,
      ),
    ]);
    expect(summary.average, closeTo(4.666, 0.01));
    expect(summary.count, 3);
  });

  testWidgets('unrated profile shows the empty rating state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerProfileScreen(
          uid: 'rated',
          loader: (_) async => const PublicPlayerProfile(
            uid: 'rated',
            displayName: 'Ana',
            level: 'Level 3',
            matches: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No ratings yet'), findsOneWidget);
  });

  testWidgets('public profile labels a numeric level explicitly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerProfileScreen(
          uid: 'rated',
          loader: (_) async => const PublicPlayerProfile(
            uid: 'rated',
            displayName: 'Ana',
            level: '3',
            matches: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('public profile load error offers a working retry', (
    tester,
  ) async {
    var attempts = 0;
    Future<PublicPlayerProfile> load(String uid) async {
      attempts++;
      if (attempts == 1) throw Exception('private backend details');
      return PublicPlayerProfile(
        uid: uid,
        displayName: 'Ana',
        level: '3',
        matches: const [],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerProfileScreen(uid: 'rated', loader: load),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load this player profile'), findsOneWidget);
    expect(find.textContaining('private backend details'), findsNothing);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('existing rating is shown instead of a second action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerProfileScreen(
          uid: 'rated',
          viewerUid: 'rater',
          viewerEmail: 'rater@example.com',
          loader: (_) async => PublicPlayerProfile(
            uid: 'rated',
            displayName: 'Ana',
            level: 'Level 3',
            email: 'rated@example.com',
            matches: [completedMatch],
            ratings: const [
              PlayerRating(
                matchId: 'completed',
                raterUid: 'rater',
                ratedUid: 'rated',
                rating: 4,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('existing-rating-completed')), findsOneWidget);
    expect(find.byKey(const Key('rate-player-completed')), findsNothing);
  });

  test(
    'completed match rating candidates exclude self and include organizer',
    () {
      expect(
        ratingCandidates(completedMatch, 'rater').map((player) => player.uid),
        ['organizer', 'rated'],
      );
      expect(
        ratingCandidates(
          completedMatch,
          'organizer',
        ).map((player) => player.uid),
        ['rater', 'rated'],
      );
    },
  );

  testWidgets('completed match exposes other players and keeps profile taps', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatePlayersSection(
            match: completedMatch,
            currentUid: 'rater',
            currentEmail: 'rater@example.com',
            ratingsLoader: (_, _) async => const [],
            ratingSubmitter: (_, _, _, _) async {},
            profileLoader: (uid) async => PublicPlayerProfile(
              uid: uid,
              displayName: 'Public player',
              level: 'Level 3',
              matches: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rating-player-rater')), findsNothing);
    expect(
      find.byKey(const Key('rate-match-player-organizer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rate-match-player-rated')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rating-player-rated')));
    await tester.pumpAndSettle();
    expect(find.text('Player Profile'), findsOneWidget);
  });

  testWidgets('submitted match rating becomes immutable completed state', (
    tester,
  ) async {
    var submitted = false;
    Future<List<PlayerRating>> load(String matchId, String raterUid) async =>
        submitted
        ? const [
            PlayerRating(
              matchId: 'completed',
              raterUid: 'rater',
              ratedUid: 'rated',
              rating: 5,
            ),
          ]
        : const [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatePlayersSection(
            match: Match(
              id: completedMatch.id,
              title: completedMatch.title,
              club: completedMatch.club,
              level: completedMatch.level,
              spotsLeft: completedMatch.spotsLeft,
              creatorUid: 'rater',
              creatorEmail: 'rater@example.com',
              players: const [
                MatchPlayer(
                  uid: 'rated',
                  email: 'rated@example.com',
                  displayName: 'Ana',
                ),
              ],
              scheduledAt: completedMatch.scheduledAt,
            ),
            currentUid: 'rater',
            ratingsLoader: load,
            ratingSubmitter: (_, _, _, rating) async {
              expect(rating, 5);
              submitted = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rate-match-player-rated')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('match-rating-star-5')));
    await tester.pump();
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rated-match-player-rated')), findsOneWidget);
    expect(find.text('Rating submitted · 5 stars'), findsOneWidget);
    expect(find.byKey(const Key('rate-match-player-rated')), findsNothing);
  });

  testWidgets('rating history load failure blocks actions and can retry', (
    tester,
  ) async {
    var attempts = 0;
    Future<List<PlayerRating>> load(String matchId, String raterUid) async {
      attempts++;
      if (attempts == 1) throw Exception('private backend details');
      return const [];
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatePlayersSection(
            match: completedMatch,
            currentUid: 'rater',
            ratingsLoader: load,
            ratingSubmitter: (_, _, _, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load submitted ratings.'), findsOneWidget);
    expect(find.textContaining('private backend details'), findsNothing);
    expect(find.byKey(const Key('rate-match-player-rated')), findsNothing);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rate-match-player-rated')), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets(
    'rating dialog announces selection and Cancel keeps card unrated',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RatePlayersSection(
              match: completedMatch,
              currentUid: 'rater',
              ratingsLoader: (_, _) async => const [],
              ratingSubmitter: (_, _, _, _) async {},
              profileLoader: (uid) async => PublicPlayerProfile(
                uid: uid,
                displayName: 'Player',
                level: '3',
                matches: const [],
              ),
              identityLoader: (uid) async => PublicPlayerProfile(
                uid: uid,
                displayName: 'Player',
                level: '3',
                matches: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileAvatar), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('rate-match-player-rated')));
      await tester.pump();
      expect(find.text('Select a rating'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit rating'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('match-rating-star-4')));
      await tester.pump();
      expect(find.text('4 of 5'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit rating'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rate-match-player-rated')), findsOneWidget);
    },
  );

  testWidgets('initial rating history shows an explicit loading state', (
    tester,
  ) async {
    final pending = Completer<List<PlayerRating>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatePlayersSection(
            match: completedMatch,
            currentUid: 'rater',
            ratingsLoader: (_, _) => pending.future,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Loading submitted ratings'), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('non-Firebase submit failure is safe and leaves others active', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatePlayersSection(
            match: completedMatch,
            currentUid: 'rater',
            ratingsLoader: (_, _) async => const [],
            ratingSubmitter: (_, _, _, _) async =>
                throw Exception('private backend details'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rate-match-player-rated')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('match-rating-star-3')));
    await tester.pump();
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(find.text('Could not submit rating.'), findsOneWidget);
    expect(find.textContaining('private backend details'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('rate-match-player-organizer')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('permission-denied remains an eligibility-safe failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatePlayersSection(
            match: completedMatch,
            currentUid: 'rater',
            ratingsLoader: (_, _) async => const [],
            ratingSubmitter: (_, _, _, _) async => throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
              message: 'private details',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rate-match-player-rated')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('match-rating-star-3')));
    await tester.pump();
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(
      find.text('This rating was already submitted or is not eligible.'),
      findsOneWidget,
    );
    expect(find.textContaining('private details'), findsNothing);
  });

  testWidgets('all submitted players remain visible in quiet resolved cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatePlayersSection(
            match: completedMatch,
            currentUid: 'rater',
            ratingsLoader: (_, _) async => const [
              PlayerRating(
                matchId: 'completed',
                raterUid: 'rater',
                ratedUid: 'organizer',
                rating: 4,
              ),
              PlayerRating(
                matchId: 'completed',
                raterUid: 'rater',
                ratedUid: 'rated',
                rating: 5,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rated-match-player-organizer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rated-match-player-rated')), findsOneWidget);
    expect(find.text('All players rated.'), findsOneWidget);
    expect(find.byKey(const Key('rate-match-player-rated')), findsNothing);
  });

  testWidgets('rating cards support narrow large-text layouts', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: RatePlayersSection(
                match: completedMatch,
                currentUid: 'rater',
                ratingsLoader: (_, _) async => const [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
