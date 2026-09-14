import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/friends.dart';
import 'package:padelx/friends_repository.dart';
import 'package:padelx/level.dart';
import 'package:padelx/location.dart';
import 'package:padelx/player_discovery.dart';
import 'package:padelx/player_discovery_repository.dart';
import 'package:padelx/players_screen.dart';

class FakeFriends implements FriendsRepository {
  @override
  Future<BlockedPlayersPage> loadBlockedPlayers({
    Object? cursor,
    int pageSize = 20,
  }) async => const BlockedPlayersPage();
  @override
  Future<void> block(String uid) async {}
  @override
  Future<void> cancel(String uid) async {}
  @override
  Future<FriendsPage> loadPage(
    String uid, {
    required String status,
    FriendDirection? direction,
    Object? cursor,
    int pageSize = 20,
  }) async => const FriendsPage();
  @override
  Future<RelationshipPolicy> policy(String uid) async =>
      const RelationshipPolicy();
  @override
  Future<void> remove(String uid) async {}
  @override
  Future<void> requestFriend(String uid) async {}
  @override
  Future<void> respond(String uid, bool accept) async {}
  @override
  Future<void> unblock(String uid) async {}
  @override
  Stream<void> watchFriendViews(String viewerUid) => const Stream.empty();
}

class FakeDiscovery implements PlayerDiscoveryRepository {
  @override
  Future<PlayerDiscoveryPage> discover(
    PlayerDiscoveryFilters filters, {
    Object? cursor,
  }) async => const PlayerDiscoveryPage();
}

class PendingDiscovery implements PlayerDiscoveryRepository {
  final calls = <PlayerDiscoveryFilters>[];
  final cursors = <Object?>[];
  final completions = <Completer<PlayerDiscoveryPage>>[];

  @override
  Future<PlayerDiscoveryPage> discover(
    PlayerDiscoveryFilters filters, {
    Object? cursor,
  }) {
    calls.add(filters);
    cursors.add(cursor);
    final completion = Completer<PlayerDiscoveryPage>();
    completions.add(completion);
    return completion.future;
  }
}

class ScriptedDiscovery implements PlayerDiscoveryRepository {
  final List<PlayerDiscoveryPage> pages;
  final calls = <PlayerDiscoveryFilters>[];
  final cursors = <Object?>[];
  ScriptedDiscovery(this.pages);

  @override
  Future<PlayerDiscoveryPage> discover(
    PlayerDiscoveryFilters filters, {
    Object? cursor,
  }) async {
    calls.add(filters);
    cursors.add(cursor);
    return pages.removeAt(0);
  }
}

void main() {
  const player = DiscoveredPlayer(
    uid: 'p',
    displayName: 'Pat',
    level: '4',
    preferredSide: 'either',
    countryCode: 'MX',
    city: 'Mexico City',
    area: 'Roma',
    ratingCount: 2,
    ratingAverage: 4.5,
    completedMatchCount: 8,
    playedTogetherCount: 2,
    isFriend: false,
    canPlayAgain: true,
    friendStatus: 'none',
    friendDirection: 'none',
  );
  test('filter payload is coarse and bounded', () {
    final map = const PlayerDiscoveryFilters(
      area: 'Roma',
      areaId: 'places/roma',
      level: '4',
      preferredSide: 'left',
    ).toMap();
    expect(map, containsPair('limit', 20));
    expect(map, isNot(contains('latitude')));
    expect(map, isNot(contains('city')));
    expect(map, containsPair('areaId', 'places/roma'));
  });
  testWidgets('level filter derives only canonical numeric options', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayersScreen(
            repository: FakeDiscovery(),
            friendsRepository: FakeFriends(),
            onProfileTap: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>).first,
    );
    expect(dropdown.items!.map((item) => item.value), [
      'any',
      ...padelLevelValues,
    ]);
  });
  testWidgets('shows city scope and remains overflow-free at mobile width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayersScreen(
            repository: FakeDiscovery(),
            friendsRepository: FakeFriends(),
            discoveryLocation: const DiscoveryLocation(
              country: 'Mexico',
              countryCode: 'MX',
              city: 'Mexico City',
            ),
            onProfileTap: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Players in\nMexico City'), findsOneWidget);
    expect(find.text('Any area'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter change during a request wins and resets pagination', (
    tester,
  ) async {
    final repository = PendingDiscovery();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayersScreen(
            repository: repository,
            friendsRepository: FakeFriends(),
            discoveryLocation: const DiscoveryLocation(
              country: 'Mexico',
              countryCode: 'MX',
              city: 'Mexico City',
            ),
            onProfileTap: (_, _) {},
          ),
        ),
      ),
    );
    expect(repository.calls, hasLength(1));
    await tester.tap(find.byKey(const Key('players-level-filter')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Level 2').last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('players-side-filter')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Left').last);
    await tester.pump();

    repository.completions.first.complete(
      const PlayerDiscoveryPage(players: [player], hasMore: true),
    );
    await tester.pump();
    expect(find.text('Pat'), findsNothing);
    await tester.pump(const Duration(milliseconds: 801));
    expect(repository.calls, hasLength(2));
    expect(repository.calls.last.level, '2');
    expect(repository.calls.last.preferredSide, 'left');
    repository.completions.last.complete(
      const PlayerDiscoveryPage(players: [player]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pat'), findsOneWidget);
  });

  testWidgets(
    'empty bounded scan exposes continuation and Load more uses cursor',
    (tester) async {
      final repository = ScriptedDiscovery([
        const PlayerDiscoveryPage(cursor: 'window-1', hasMore: true),
        const PlayerDiscoveryPage(players: [player]),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayersScreen(
              repository: repository,
              friendsRepository: FakeFriends(),
              discoveryLocation: const DiscoveryLocation(
                country: 'Mexico',
                countryCode: 'MX',
                city: 'Mexico City',
              ),
              onProfileTap: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('players-more-available')), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(repository.cursors, [null, 'window-1']);
      expect(find.text('Pat'), findsOneWidget);
    },
  );

  testWidgets('pull to refresh resets pagination and replaces stale rows', (
    tester,
  ) async {
    const refreshedPlayer = DiscoveredPlayer(
      uid: 'new',
      displayName: 'New player',
      level: '4',
      preferredSide: 'either',
      countryCode: 'MX',
      city: 'Mexico City',
      area: '',
      ratingCount: 0,
      ratingAverage: 0,
      completedMatchCount: 0,
      playedTogetherCount: 0,
      isFriend: false,
      canPlayAgain: false,
      friendStatus: 'none',
      friendDirection: 'none',
    );
    final repository = ScriptedDiscovery([
      const PlayerDiscoveryPage(
        players: [player],
        cursor: 'page-1',
        hasMore: true,
      ),
      const PlayerDiscoveryPage(players: [refreshedPlayer]),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayersScreen(
            repository: repository,
            friendsRepository: FakeFriends(),
            discoveryLocation: const DiscoveryLocation(
              country: 'Mexico',
              countryCode: 'MX',
              city: 'Mexico City',
              cityId: 'places/mexico-city',
            ),
            onProfileTap: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pat'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('players-scroll-view')),
      const Offset(0, 350),
    );
    await tester.pumpAndSettle();
    expect(repository.cursors, [null, null]);
    expect(find.text('Pat'), findsNothing);
    expect(find.text('New player'), findsOneWidget);
    expect(repository.calls.last, repository.calls.first);
  });

  testWidgets(
    'overlapping refreshes coalesce and stale refresh cannot overwrite',
    (tester) async {
      const refreshedPlayer = DiscoveredPlayer(
        uid: 'new',
        displayName: 'Latest player',
        level: '4',
        preferredSide: 'either',
        countryCode: 'MX',
        city: 'Mexico City',
        area: '',
        ratingCount: 0,
        ratingAverage: 0,
        completedMatchCount: 0,
        playedTogetherCount: 0,
        isFriend: false,
        canPlayAgain: false,
        friendStatus: 'none',
        friendDirection: 'none',
      );
      final repository = PendingDiscovery();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayersScreen(
              repository: repository,
              friendsRepository: FakeFriends(),
              discoveryLocation: const DiscoveryLocation(
                country: 'Mexico',
                countryCode: 'MX',
                city: 'Mexico City',
              ),
              onProfileTap: (_, _) {},
            ),
          ),
        ),
      );
      repository.completions.single.complete(
        const PlayerDiscoveryPage(
          players: [player],
          cursor: 'page-1',
          hasMore: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Load more'));
      await tester.pump();
      expect(repository.calls, hasLength(2));
      final refresh = tester.state<RefreshIndicatorState>(
        find.byType(RefreshIndicator),
      );
      unawaited(refresh.show());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(repository.calls, hasLength(2));
      unawaited(refresh.show());
      await tester.pump();
      expect(repository.calls, hasLength(2));

      repository.completions[1].complete(
        const PlayerDiscoveryPage(players: [player]),
      );
      await tester.pump();
      expect(find.text('Pat'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 801));
      expect(repository.calls, hasLength(3));
      expect(repository.cursors.last, isNull);
      repository.completions[2].complete(
        const PlayerDiscoveryPage(players: [refreshedPlayer]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Latest player'), findsOneWidget);
      expect(find.text('Pat'), findsNothing);
    },
  );

  testWidgets('canonical location change reloads and clears only area filter', (
    tester,
  ) async {
    final repository = PendingDiscovery();
    Widget screen(DiscoveryLocation location) => MaterialApp(
      home: Scaffold(
        body: PlayersScreen(
          repository: repository,
          friendsRepository: FakeFriends(),
          discoveryLocation: location,
          onProfileTap: (_, _) {},
        ),
      ),
    );
    const mexico = DiscoveryLocation(
      country: 'Mexico',
      countryCode: 'MX',
      city: 'Mexico City',
      cityId: 'places/mexico-city',
    );
    await tester.pumpWidget(screen(mexico));
    repository.completions.single.complete(
      const PlayerDiscoveryPage(players: [player]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('players-level-filter')));
    await tester.pump();
    await tester.tap(find.text('Level 2').last);
    await tester.pump(const Duration(milliseconds: 801));
    repository.completions.last.complete(const PlayerDiscoveryPage());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      screen(
        const DiscoveryLocation(
          country: 'Mexico',
          countryCode: 'MX',
          city: 'Guadalajara',
          cityId: 'places/guadalajara',
          area: 'Americana',
          areaId: 'places/americana',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 801));
    expect(repository.calls.last.level, '2');
    expect(repository.calls.last.area, isEmpty);
    expect(repository.calls.last.areaId, isEmpty);
    expect(repository.cursors.last, isNull);
    repository.completions.last.complete(const PlayerDiscoveryPage());
    await tester.pumpAndSettle();
    expect(find.text('Players in\nGuadalajara'), findsOneWidget);
  });

  testWidgets('legacy city display change also reloads discovery', (
    tester,
  ) async {
    final repository = PendingDiscovery();
    Widget screen(String city) => MaterialApp(
      home: Scaffold(
        body: PlayersScreen(
          repository: repository,
          friendsRepository: FakeFriends(),
          discoveryLocation: DiscoveryLocation(
            country: 'Mexico',
            countryCode: 'MX',
            city: city,
          ),
          onProfileTap: (_, _) {},
        ),
      ),
    );
    await tester.pumpWidget(screen('Mexico City'));
    repository.completions.single.complete(const PlayerDiscoveryPage());
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen('Guadalajara'));
    await tester.pump(const Duration(milliseconds: 801));
    expect(repository.calls, hasLength(2));
    repository.completions.last.complete(const PlayerDiscoveryPage());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'player card shows public context and safe actions without Message',
    (tester) async {
      var opened = false;
      var replayed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerDiscoveryCard(
              player: player,
              friendsRepository: FakeFriends(),
              onTap: () => opened = true,
              onChanged: () {},
              onPlayAgain: () => replayed = true,
            ),
          ),
        ),
      );
      expect(find.text('Pat'), findsOneWidget);
      expect(find.text('Roma, Mexico City'), findsOneWidget);
      expect(find.text('Played together 2 times'), findsOneWidget);
      expect(find.text('Message'), findsNothing);
      await tester.tap(find.text('Pat'));
      expect(opened, true);
      await tester.tap(find.text('Play Again'));
      expect(replayed, true);
    },
  );
}
