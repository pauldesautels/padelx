import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/friends.dart';
import 'package:padelx/friends_repository.dart';
import 'package:padelx/player_discovery.dart';
import 'package:padelx/players_screen.dart';

class FakeFriends implements FriendsRepository {
  @override Future<void> block(String uid) async {} @override Future<void> cancel(String uid) async {}
  @override Future<FriendsPage> loadPage(String uid, {required String status, FriendDirection? direction, Object? cursor, int pageSize = 20}) async => const FriendsPage();
  @override Future<RelationshipPolicy> policy(String uid) async => const RelationshipPolicy();
  @override Future<void> remove(String uid) async {} @override Future<void> requestFriend(String uid) async {}
  @override Future<void> respond(String uid, bool accept) async {} @override Future<void> unblock(String uid) async {}
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
