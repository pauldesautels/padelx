import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/played_with.dart';
import 'package:padelx/played_with_repository.dart';
import 'package:padelx/played_with_screen.dart';
import 'package:padelx/social_profile.dart';

class FakePlayedWithRepository implements PlayedWithRepository {
  final List<PlayedWithPage> pages;
  final Map<String, PlayedWithRelationship> relationships;
  int calls = 0;
  final List<int> requestedSizes = [];

  FakePlayedWithRepository({
    this.pages = const [],
    this.relationships = const {},
  });

  @override
  Future<PlayedWithPage> loadPage(
    String viewerUid, {
    Object? cursor,
    int pageSize = 20,
  }) async {
    requestedSizes.add(pageSize);
    return pages[calls++];
  }

  @override
  Future<PlayedWithRelationship?> relationship(
    String viewerUid,
    String otherUid,
  ) async => relationships[otherUid];
}

PlayedWithPlayer player(
  String uid, {
  DateTime? lastPlayedAt,
  int together = 1,
  int ratingCount = 0,
  double ratingAverage = 0,
}) => PlayedWithPlayer(
  relationship: PlayedWithRelationship(
    otherUid: uid,
    lastPlayedAt: lastPlayedAt,
    completedMatchCount: together,
  ),
  profile: PlayedWithPublicProfile(
    uid: uid,
    displayName: 'Player $uid',
    level: '3.5',
    ratingCount: ratingCount,
    ratingAverage: ratingAverage,
    socialProfile: const SocialProfileData(preferredSide: PreferredSide.right),
  ),
);

void main() {
  test('playedWith parsing uses safe compatibility defaults', () {
    final item = PlayedWithRelationship.fromMap({
      'otherUid': 'other',
      'completedMatchCount': 3.0,
    });
    expect(item.otherUid, 'other');
    expect(item.completedMatchCount, 3);
    expect(item.lastPlayedAt, isNull);

    final profile = PlayedWithPublicProfile.fromMap('other', const {});
    expect(profile.ratingAverage, 0);
    expect(profile.ratingCount, 0);
    expect(profile.completedMatchCount, 0);
    expect(profile.repeatPlayerCount, 0);
  });

  test('playedWith ordering is descending and null-safe', () {
    final sorted = sortPlayedWithPlayers([
      player('old', lastPlayedAt: DateTime(2026, 1, 1)),
      player('missing'),
      player('new', lastPlayedAt: DateTime(2026, 9, 4)),
    ]);
    expect(sorted.map((item) => item.profile.uid), ['new', 'old', 'missing']);
  });

  testWidgets('legacy empty account has a friendly empty state', (
    tester,
  ) async {
    final repository = FakePlayedWithRepository(
      pages: const [PlayedWithPage()],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlayedWithScreen(
          viewerUid: 'viewer',
          repository: repository,
          onProfileTap: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'People you play with will appear here after completed matches.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('full list paginates with a cursor and keeps both pages', (
    tester,
  ) async {
    final repository = FakePlayedWithRepository(
      pages: [
        PlayedWithPage(players: [player('a')], cursor: 'page-1', hasMore: true),
        PlayedWithPage(players: [player('b')], cursor: 'page-2'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlayedWithScreen(
          viewerUid: 'viewer',
          repository: repository,
          onProfileTap: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('played-with-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('Player a'), findsOneWidget);
    expect(find.text('Player b'), findsOneWidget);
    expect(repository.calls, 2);
    expect(repository.requestedSizes, [20, 20]);
  });

  testWidgets('Home preview is capped and View All navigates', (tester) async {
    final repository = FakePlayedWithRepository(
      pages: [PlayedWithPage(players: List.generate(5, (i) => player('$i')))],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayedWithPreview(
            viewerUid: 'viewer',
            repository: repository,
            onProfileTap: (_, _) {},
            onViewAll: () =>
                Navigator.of(tester.element(find.byType(Scaffold))).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(body: Text('All players')),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlayedWithTile), findsNWidgets(3));
    expect(repository.requestedSizes, [3]);
    await tester.tap(find.byKey(const Key('played-with-view-all')));
    await tester.pumpAndSettle();
    expect(find.text('All players'), findsOneWidget);
  });

  testWidgets('row exposes social context but no private data', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayedWithTile(
            player: player(
              'safe',
              lastPlayedAt: DateTime(2026, 9, 4),
              together: 3,
              ratingCount: 4,
              ratingAverage: 4.5,
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Right side'), findsOneWidget);
    expect(find.textContaining('4.5 ★ (4)'), findsOneWidget);
    expect(find.textContaining('3 matches together'), findsOneWidget);
    expect(find.textContaining('Sep 4'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });
}
