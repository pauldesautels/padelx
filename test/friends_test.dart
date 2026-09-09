import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/friends.dart';
import 'package:padelx/friends_repository.dart';
import 'package:padelx/friends_screen.dart';
import 'package:padelx/played_with.dart';

class FakeFriendsRepository implements FriendsRepository {
  final Map<String, RelationshipPolicy> policies;
  final List<Object> policyResponses;
  final Object? requestFailure;
  final List<String> actions = [];
  final Map<String, List<FriendsPage>> pages;
  final Map<String, int> calls = {};
  int policyCalls = 0;
  int requestCalls = 0;
  FakeFriendsRepository({
    this.policies = const {},
    this.policyResponses = const [],
    this.requestFailure,
    this.pages = const {},
  });
  String key(String status, FriendDirection? direction) =>
      '$status-${direction?.name}';
  @override
  Future<RelationshipPolicy> policy(String uid) async {
    final index = policyCalls++;
    if (index < policyResponses.length) {
      final response = policyResponses[index];
      if (response is RelationshipPolicy) return response;
      throw response;
    }
    return policies[uid] ?? const RelationshipPolicy();
  }

  @override
  Future<FriendsPage> loadPage(
    String uid, {
    required String status,
    FriendDirection? direction,
    Object? cursor,
    int pageSize = 20,
  }) async {
    final k = key(status, direction);
    final index = calls[k] ?? 0;
    calls[k] = index + 1;
    return pages[k]?[index] ?? const FriendsPage();
  }

  Future<void> record(String name, String uid) async =>
      actions.add('$name:$uid');
  @override
  Future<void> requestFriend(String uid) async {
    requestCalls++;
    actions.add('request:$uid');
    if (requestFailure != null) throw requestFailure!;
  }

  @override
  Future<void> respond(String uid, bool accept) =>
      record(accept ? 'accept' : 'decline', uid);
  @override
  Future<void> cancel(String uid) => record('cancel', uid);
  @override
  Future<void> remove(String uid) => record('remove', uid);
  @override
  Future<void> block(String uid) => record('block', uid);
  @override
  Future<void> unblock(String uid) => record('unblock', uid);
}

PlayedWithPublicProfile profile(String uid) =>
    PlayedWithPublicProfile(uid: uid, displayName: 'Player $uid', level: '3');
FriendView view(String uid, String status, FriendDirection direction) =>
    FriendView(
      otherUid: uid,
      friendshipId: 'pair-$uid',
      status: status,
      direction: direction,
    );

void main() {
  const none = RelationshipPolicy();
  const outgoing = RelationshipPolicy(
    status: 'pending',
    direction: FriendDirection.outgoing,
  );
  const accepted = RelationshipPolicy(
    status: 'accepted',
    direction: FriendDirection.mutual,
  );

  Widget friendAction(
    FakeFriendsRepository repository, {
    VoidCallback? onChanged,
  }) => MaterialApp(
    home: Scaffold(
      body: FriendAction(
        targetUid: 'target',
        repository: repository,
        onChanged: onChanged,
      ),
    ),
  );

  for (final entry in <String, RelationshipPolicy>{
    'new': const RelationshipPolicy(),
    'out': const RelationshipPolicy(
      status: 'pending',
      direction: FriendDirection.outgoing,
    ),
    'in': const RelationshipPolicy(
      status: 'pending',
      direction: FriendDirection.incoming,
    ),
    'friend': const RelationshipPolicy(
      status: 'accepted',
      direction: FriendDirection.mutual,
    ),
    'blocked': const RelationshipPolicy(interactionAllowed: false),
  }.entries) {
    testWidgets('friend action renders ${entry.key} state', (tester) async {
      final repository = FakeFriendsRepository(
        policies: {entry.key: entry.value},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendAction(targetUid: entry.key, repository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final expected = {
        'new': 'Add Friend',
        'out': 'Requested',
        'in': 'Accept',
        'friend': 'Friends',
        'blocked': null,
      }[entry.key];
      if (expected == null) {
        expect(find.byType(ButtonStyleButton), findsNothing);
      } else {
        expect(find.text(expected), findsOneWidget);
      }
    });
  }

  testWidgets('incoming request accepts and outgoing request cancels', (
    tester,
  ) async {
    final repository = FakeFriendsRepository(
      policies: {
        'in': const RelationshipPolicy(
          status: 'pending',
          direction: FriendDirection.incoming,
        ),
        'out': const RelationshipPolicy(
          status: 'pending',
          direction: FriendDirection.outgoing,
        ),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              FriendAction(targetUid: 'in', repository: repository),
              FriendAction(targetUid: 'out', repository: repository),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requested'));
    await tester.pumpAndSettle();
    expect(repository.actions, ['accept:in', 'cancel:out']);
  });

  testWidgets('successful Add Friend mutation renders Requested', (
    tester,
  ) async {
    final repository = FakeFriendsRepository(
      policyResponses: const [none, outgoing],
    );
    await tester.pumpWidget(friendAction(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Friend'));
    await tester.pumpAndSettle();

    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('This social action is unavailable.'), findsNothing);
    expect(repository.requestCalls, 1);
  });

  testWidgets(
    'failed Add Friend reconciles outgoing request without false failure',
    (tester) async {
      final repository = FakeFriendsRepository(
        policyResponses: const [none, outgoing],
        requestFailure: Exception('ambiguous response'),
      );
      await tester.pumpWidget(friendAction(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Friend'));
      await tester.pumpAndSettle();

      expect(find.text('Requested'), findsOneWidget);
      expect(find.text('This social action is unavailable.'), findsNothing);
      expect(repository.requestCalls, 1);
    },
  );

  testWidgets('failed Add Friend reconciles accepted without false failure', (
    tester,
  ) async {
    final repository = FakeFriendsRepository(
      policyResponses: const [none, accepted],
      requestFailure: Exception('ambiguous response'),
    );
    await tester.pumpWidget(friendAction(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Friend'));
    await tester.pumpAndSettle();

    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('This social action is unavailable.'), findsNothing);
    expect(repository.requestCalls, 1);
  });

  testWidgets('failed Add Friend with no relationship shows failure', (
    tester,
  ) async {
    final repository = FakeFriendsRepository(
      policyResponses: const [none, none],
      requestFailure: Exception('failed mutation'),
    );
    await tester.pumpWidget(friendAction(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Friend'));
    await tester.pump();

    expect(find.text('This social action is unavailable.'), findsOneWidget);
    expect(repository.requestCalls, 1);
  });

  testWidgets('failed Add Friend with failed reconciliation shows failure', (
    tester,
  ) async {
    final repository = FakeFriendsRepository(
      policyResponses: [none, Exception('failed policy')],
      requestFailure: Exception('failed mutation'),
    );
    await tester.pumpWidget(friendAction(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Friend'));
    await tester.pump();

    expect(find.text('This social action is unavailable.'), findsOneWidget);
    expect(repository.requestCalls, 1);
  });

  testWidgets('post-success refresh failure does not report mutation failure', (
    tester,
  ) async {
    final repository = FakeFriendsRepository(
      policyResponses: const [none, outgoing],
    );
    await tester.pumpWidget(
      friendAction(repository, onChanged: () => throw Exception('refresh')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Friend'));
    await tester.pumpAndSettle();

    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('This social action is unavailable.'), findsNothing);
    expect(repository.requestCalls, 1);
  });

  testWidgets('friends screen has empty states and bounded load more', (
    tester,
  ) async {
    final first = FriendsPage(
      views: [view('a', 'accepted', FriendDirection.mutual)],
      profiles: {'a': profile('a')},
      cursor: 'one',
      hasMore: true,
    );
    final second = FriendsPage(
      views: [view('b', 'accepted', FriendDirection.mutual)],
      profiles: {'b': profile('b')},
    );
    final repository = FakeFriendsRepository(
      pages: {
        'accepted-null': [first, second],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(viewerUid: 'viewer', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No requests.'), findsNWidgets(2));
    expect(find.text('Player a'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Player b'), findsOneWidget);
    expect(repository.calls['accepted-null'], 2);
  });
}
