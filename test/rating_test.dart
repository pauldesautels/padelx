import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/main.dart';

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
    expect(find.text('Submitted · 5 ★'), findsOneWidget);
    expect(find.byKey(const Key('rate-match-player-rated')), findsNothing);
  });
}
