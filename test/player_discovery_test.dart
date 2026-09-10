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
  @override Future<BlockedPlayersPage> loadBlockedPlayers({Object? cursor, int pageSize = 20}) async => const BlockedPlayersPage();
  @override Future<void> block(String uid) async {} @override Future<void> cancel(String uid) async {}
  @override Future<FriendsPage> loadPage(String uid, {required String status, FriendDirection? direction, Object? cursor, int pageSize = 20}) async => const FriendsPage();
  @override Future<RelationshipPolicy> policy(String uid) async => const RelationshipPolicy();
  @override Future<void> remove(String uid) async {} @override Future<void> requestFriend(String uid) async {}
  @override Future<void> respond(String uid, bool accept) async {} @override Future<void> unblock(String uid) async {}
  @override Stream<void> watchFriendViews(String viewerUid) => const Stream.empty();
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
  final completions = <Completer<PlayerDiscoveryPage>>[];

  @override
  Future<PlayerDiscoveryPage> discover(
    PlayerDiscoveryFilters filters, {
    Object? cursor,
  }) {
    calls.add(filters);
    final completion = Completer<PlayerDiscoveryPage>();
    completions.add(completion);
    return completion.future;
  }
}

void main() {
  const player = DiscoveredPlayer(uid: 'p', displayName: 'Pat', level: '4', preferredSide: 'either',
    countryCode: 'MX', city: 'Mexico City', area: 'Roma', ratingCount: 2, ratingAverage: 4.5,
    completedMatchCount: 8, playedTogetherCount: 2, isFriend: false, canPlayAgain: true,
    friendStatus: 'none', friendDirection: 'none');
  test('filter payload is coarse and bounded', () {
    final map = const PlayerDiscoveryFilters(area: 'Roma', level: '4', preferredSide: 'left').toMap();
    expect(map, containsPair('limit', 20)); expect(map, isNot(contains('latitude'))); expect(map, isNot(contains('city')));
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
  testWidgets('player card shows public context and safe actions without Message', (tester) async {
    var opened = false; var replayed = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlayerDiscoveryCard(player: player,
      friendsRepository: FakeFriends(), onTap: () => opened = true, onChanged: () {}, onPlayAgain: () => replayed = true))));
    expect(find.text('Pat'), findsOneWidget); expect(find.text('Roma, Mexico City'), findsOneWidget);
    expect(find.text('Played together 2 times'), findsOneWidget); expect(find.text('Message'), findsNothing);
    await tester.tap(find.text('Pat')); expect(opened, true);
    await tester.tap(find.text('Play Again')); expect(replayed, true);
  });
}
