import 'dart:async';

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
  final Future<FriendsPage> Function(String key, int call, Object? cursor)?
  loadPageHandler;
  final Map<String, int> calls = {};
  int policyCalls = 0;
  int requestCalls = 0;
  int watchCalls = 0;
  int watchCancels = 0;
  final StreamController<void> friendViews = StreamController<void>.broadcast();
  FakeFriendsRepository({
    this.policies = const {},
    this.policyResponses = const [],
    this.requestFailure,
    this.pages = const {},
    this.loadPageHandler,
  });
  String key(String status, FriendDirection? direction) =>
      '$status-${direction?.name}';
  @override
  Stream<void> watchFriendViews(String uid) {
    watchCalls++;
    late StreamSubscription<void> source;
    late StreamController<void> proxy;
    proxy = StreamController<void>(
      onListen: () {
        source = friendViews.stream.listen(proxy.add, onError: proxy.addError);
      },
      onCancel: () async {
        watchCancels++;
        await source.cancel();
      },
    );
    return proxy.stream;
  }

  void emitFriendViewsChange() => friendViews.add(null);
  void failFriendViewsListener() => friendViews.addError(Exception('listen'));
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
    if (loadPageHandler != null) {
      return loadPageHandler!(k, index, cursor);
    }
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

FriendsPage page(String uid, String status, FriendDirection direction) =>
    FriendsPage(
      views: [view(uid, status, direction)],
      profiles: {uid: profile(uid)},
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

  testWidgets('friendViews listener starts once and skips initial snapshot', (
    tester,
  ) async {
    final repository = FakeFriendsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(viewerUid: 'viewer', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.watchCalls, 1);
    expect(repository.calls.values, everyElement(1));
    repository.emitFriendViewsChange();
    await tester.pumpAndSettle();
    expect(repository.calls.values, everyElement(1));

    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(viewerUid: 'viewer', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.watchCalls, 1);
  });

  testWidgets('remote acceptance moves request into accepted friends', (
    tester,
  ) async {
    final repository = FakeFriendsRepository(
      pages: {
        'pending-incoming': const [FriendsPage(), FriendsPage()],
        'pending-outgoing': [
          page('remote', 'pending', FriendDirection.outgoing),
          const FriendsPage(),
        ],
        'accepted-null': [
          const FriendsPage(),
          page('remote', 'accepted', FriendDirection.mutual),
        ],
      },
      policies: {'remote': outgoing},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(viewerUid: 'viewer', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('friends-section-Outgoing Requests')),
        matching: find.text('Player remote'),
      ),
      findsOneWidget,
    );

    repository.emitFriendViewsChange();
    await tester.pumpAndSettle();
    repository.emitFriendViewsChange();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('friends-section-Accepted Friends')),
        matching: find.text('Player remote'),
      ),
      findsOneWidget,
    );
    expect(find.text('No requests.'), findsNWidgets(2));
  });

  for (final scenario in <String, Map<String, List<FriendsPage>>>{
    'remote incoming request appears': {
      'pending-incoming': [
        const FriendsPage(),
        page('incoming', 'pending', FriendDirection.incoming),
      ],
    },
    'remote outgoing request appears': {
      'pending-outgoing': [
        const FriendsPage(),
        page('outgoing', 'pending', FriendDirection.outgoing),
      ],
    },
  }.entries) {
    testWidgets(scenario.key, (tester) async {
      final repository = FakeFriendsRepository(pages: scenario.value);
      await tester.pumpWidget(
        MaterialApp(
          home: FriendsScreen(viewerUid: 'viewer', repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      repository.emitFriendViewsChange();
      await tester.pumpAndSettle();
      repository.emitFriendViewsChange();
      await tester.pumpAndSettle();
      expect(find.textContaining('Player '), findsOneWidget);
    });
  }

  for (final scenario in <String, String>{
    'remote decline removes incoming request': 'pending-incoming',
    'remote cancellation removes outgoing request': 'pending-outgoing',
    'remote friend removal removes accepted friend': 'accepted-null',
    'blocking-related removal updates friends': 'accepted-null',
  }.entries) {
    testWidgets(scenario.key, (tester) async {
      final parts = scenario.value.split('-');
      final status = parts.first;
      final direction = parts.last == 'null'
          ? FriendDirection.mutual
          : FriendDirection.values.byName(parts.last);
      final repository = FakeFriendsRepository(
        pages: {
          scenario.value: [
            page('removed', status, direction),
            const FriendsPage(),
          ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FriendsScreen(viewerUid: 'viewer', repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Player removed'), findsOneWidget);
      repository.emitFriendViewsChange();
      await tester.pumpAndSettle();
      repository.emitFriendViewsChange();
      await tester.pumpAndSettle();
      expect(find.text('Player removed'), findsNothing);
    });
  }

  testWidgets('snapshot bursts coalesce with one follow-up refresh', (
    tester,
  ) async {
    final active = <String, Completer<FriendsPage>>{};
    final followUp = <String, Completer<FriendsPage>>{};
    final repository = FakeFriendsRepository(
      loadPageHandler: (key, call, _) {
        if (call == 0) return Future.value(const FriendsPage());
        final completer = Completer<FriendsPage>();
        (call == 1 ? active : followUp)[key] = completer;
        return completer.future;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(viewerUid: 'viewer', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    repository.emitFriendViewsChange();
    await tester.pump();
    repository.emitFriendViewsChange();
    await tester.pump();
    repository.emitFriendViewsChange();
    await tester.pump();
    expect(repository.calls.values, everyElement(2));

    for (final completer in active.values) {
      completer.complete(const FriendsPage());
    }
    await tester.pump();
    await tester.pump();
    expect(repository.calls.values, everyElement(3));
    for (final completer in followUp.values) {
      completer.complete(const FriendsPage());
    }
    await tester.pumpAndSettle();
    expect(repository.calls.values, everyElement(3));
  });

  testWidgets('authoritative refresh resets pagination to the first page', (
    tester,
  ) async {
    final cursors = <Object?>[];
    final repository = FakeFriendsRepository(
      loadPageHandler: (key, call, cursor) async {
        if (key != 'accepted-null') return const FriendsPage();
        cursors.add(cursor);
        if (call == 0) {
          return FriendsPage(
            views: [view('first', 'accepted', FriendDirection.mutual)],
            profiles: {'first': profile('first')},
            cursor: 'page-one',
            hasMore: true,
          );
        }
        return const FriendsPage();
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(viewerUid: 'viewer', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    repository.emitFriendViewsChange();
    await tester.pumpAndSettle();
    repository.emitFriendViewsChange();
    await tester.pumpAndSettle();
    expect(cursors, [null, 'page-one', null]);
  });

  testWidgets('listener failure preserves content and disposal cancels it', (
    tester,
  ) async {
    final repository = FakeFriendsRepository(
      pages: {
        'accepted-null': [page('existing', 'accepted', FriendDirection.mutual)],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(viewerUid: 'viewer', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    repository.failFriendViewsListener();
    await tester.pump();
    expect(find.text('Player existing'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(repository.watchCancels, 1);
  });

  testWidgets('failed authoritative refresh preserves existing content', (
    tester,
  ) async {
    final repository = FakeFriendsRepository(
      loadPageHandler: (key, call, _) async {
        if (key == 'accepted-null' && call == 0) {
          return page('existing', 'accepted', FriendDirection.mutual);
        }
        if (call > 0) throw Exception('refresh');
        return const FriendsPage();
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(viewerUid: 'viewer', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    repository.emitFriendViewsChange();
    await tester.pumpAndSettle();
    repository.emitFriendViewsChange();
    await tester.pumpAndSettle();
    expect(find.text('Player existing'), findsOneWidget);
  });
}
