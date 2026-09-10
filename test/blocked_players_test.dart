import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/blocked_players_screen.dart';
import 'package:padelx/friends.dart';
import 'package:padelx/friends_repository.dart';

class _BlockedRepository implements FriendsRepository {
  final List<Object> responses;
  final Future<void> Function(String uid)? unblockHandler;
  int loads = 0;
  int unblocks = 0;
  final List<Object?> cursors = [];

  _BlockedRepository({this.responses = const [], this.unblockHandler});

  @override
  Future<BlockedPlayersPage> loadBlockedPlayers({
    Object? cursor,
    int pageSize = 20,
  }) async {
    cursors.add(cursor);
    final response = responses[loads++];
    if (response is BlockedPlayersPage) return response;
    if (response is Future<BlockedPlayersPage>) return response;
    throw response;
  }

  @override
  Future<void> unblock(String uid) async {
    unblocks++;
    await unblockHandler?.call(uid);
  }

  @override
  Future<void> block(String uid) async {}
  @override
  Future<void> cancel(String uid) async {}
  @override
  Future<FriendsPage> loadPage(
    String viewerUid, {
    required String status,
    FriendDirection? direction,
    Object? cursor,
    int pageSize = 20,
  }) async => const FriendsPage();
  @override
  Future<RelationshipPolicy> policy(String targetUid) async =>
      const RelationshipPolicy();
  @override
  Future<void> remove(String uid) async {}
  @override
  Future<void> requestFriend(String targetUid) async {}
  @override
  Future<void> respond(String requesterUid, bool accept) async {}
  @override
  Stream<void> watchFriendViews(String viewerUid) => const Stream.empty();
}

const _available = BlockedPlayer(
  uid: 'one',
  displayName: 'Player One',
  level: '3.5',
);
const _unavailable = BlockedPlayer(
  uid: 'gone',
  displayName: 'Unavailable player',
  unavailable: true,
);

void main() {
  testWidgets('shows loading then empty blocked-player state', (tester) async {
    final pending = Completer<BlockedPlayersPage>();
    final repository = _BlockedRepository(responses: [pending.future]);
    await tester.pumpWidget(
      MaterialApp(home: BlockedPlayersScreen(repository: repository)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const BlockedPlayersPage());
    await tester.pumpAndSettle();
    expect(find.text('You have not blocked any players.'), findsOneWidget);
  });

  testWidgets('lists players, unavailable fallback, and paginates', (
    tester,
  ) async {
    final repository = _BlockedRepository(
      responses: const [
        BlockedPlayersPage(
          players: [_available],
          cursor: 'page-one',
          hasMore: true,
        ),
        BlockedPlayersPage(players: [_unavailable]),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: BlockedPlayersScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Player One'), findsOneWidget);
    expect(find.text('Level 3.5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('blocked-players-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable player'), findsOneWidget);
    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(repository.cursors, [null, 'page-one']);
  });

  testWidgets('load failure offers retry', (tester) async {
    final repository = _BlockedRepository(
      responses: [Exception('offline'), const BlockedPlayersPage()],
    );
    await tester.pumpWidget(
      MaterialApp(home: BlockedPlayersScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('You have not blocked any players.'), findsOneWidget);
  });

  testWidgets('successful unblock removes row and ignores duplicate tap', (
    tester,
  ) async {
    final pending = Completer<void>();
    final repository = _BlockedRepository(
      responses: const [
        BlockedPlayersPage(players: [_available]),
      ],
      unblockHandler: (_) => pending.future,
    );
    await tester.pumpWidget(
      MaterialApp(home: BlockedPlayersScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('unblock-one')));
    await tester.pump();
    expect(find.text('Unblocking…'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('unblock-one')),
      warnIfMissed: false,
    );
    expect(repository.unblocks, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Player One'), findsNothing);
    expect(find.textContaining('Friendship is not restored'), findsOneWidget);
  });

  testWidgets('failed unblock preserves row and shows safe error', (
    tester,
  ) async {
    final repository = _BlockedRepository(
      responses: const [
        BlockedPlayersPage(players: [_available]),
      ],
      unblockHandler: (_) async => throw Exception('failure'),
    );
    await tester.pumpWidget(
      MaterialApp(home: BlockedPlayersScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('unblock-one')));
    await tester.pumpAndSettle();
    expect(find.text('Player One'), findsOneWidget);
    expect(find.text('This social action is unavailable.'), findsOneWidget);
  });
}
