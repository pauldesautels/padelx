import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/conversation_screen.dart';
import 'package:padelx/messages_screen.dart';
import 'package:padelx/messaging.dart';
import 'package:padelx/messaging_repository.dart';

class FakeMessagingRepository implements MessagingRepository {
  bool readOnly;
  int messageLoads = 0;
  int markReads = 0;
  int sends = 0;
  String? sentText;
  void Function()? onMarkRead;
  final StreamController<String> inboxInvalidations =
      StreamController<String>.broadcast();
  int inboxListens = 0;
  int inboxCancellations = 0;
  int conversationLoads = 0;
  final List<String?> conversationBefores = [];
  final List<Object> conversationResponses;
  FakeMessagingRepository({
    this.readOnly = false,
    this.conversationResponses = const [],
  });
  @override
  Stream<String> watchInboxInvalidations(String currentUid) {
    inboxListens++;
    late StreamSubscription<String> source;
    late StreamController<String> proxy;
    proxy = StreamController<String>(
      onListen: () {
        source = inboxInvalidations.stream.listen(
          proxy.add,
          onError: proxy.addError,
        );
      },
      onCancel: () async {
        inboxCancellations++;
        await source.cancel();
      },
    );
    return proxy.stream;
  }

  void emitInboxVersion(String version) => inboxInvalidations.add(version);
  void failInboxListener() => inboxInvalidations.addError(Exception('listen'));
  @override
  Future<String> ensureDirect(String otherUid) async => 'direct-id';
  @override
  Future<({bool canSend, String conversationId, String? disabledReason})>
  ensureMatch(String matchId) async => (
    conversationId: 'match-id',
    canSend: !readOnly,
    disabledReason: readOnly ? 'This match was cancelled.' : null,
  );
  @override
  Future<ConversationsPage> conversations({
    String? before,
    int limit = 20,
  }) async {
    conversationBefores.add(before);
    final call = conversationLoads++;
    if (call < conversationResponses.length) {
      final response = conversationResponses[call];
      if (response is Future<ConversationsPage>) return await response;
      if (response is ConversationsPage) return response;
      throw response;
    }
    return ConversationsPage([
      const ConversationSummary(
        id: 'direct-id',
        type: 'direct',
        otherUid: 'friend',
        preview: 'Thursday?',
        unreadCount: 2,
      ),
      const ConversationSummary(
        id: 'match-id',
        type: 'match',
        matchId: 'match',
        preview: 'Court 2',
      ),
    ]);
  }

  @override
  Future<MessagesPage> messages(
    String conversationId, {
    String? before,
    int limit = 40,
  }) async {
    messageLoads++;
    return MessagesPage(
      [const ChatMessage(id: 'one', senderUid: 'friend', text: 'Hello')],
      canSend: !readOnly,
      disabledReason: readOnly ? 'This conversation is read-only.' : null,
    );
  }

  @override
  Future<void> markRead(String conversationId) async {
    markReads++;
    onMarkRead?.call();
  }

  @override
  Future<void> send(
    String conversationId,
    String text,
    String requestId,
  ) async {
    sends++;
    sentText = text;
  }

  @override
  Future<Map<String, String>> directNames(Iterable<String> uids) async => {
    'friend': 'Alex',
  };
  @override
  Future<Map<String, String>> matchNames(Iterable<String> ids) async => {
    'match': 'Club X',
  };
}

void main() {
  const oldMatch = ConversationSummary(
    id: 'match-id',
    type: 'match',
    matchId: 'match',
    preview: 'live test 2',
  );
  const updatedMatch = ConversationSummary(
    id: 'match-id',
    type: 'match',
    matchId: 'match',
    preview: 'inbox live test',
    unreadCount: 1,
  );

  Widget inbox(
    FakeMessagingRepository repository, {
    ConversationNotificationStream? conversationNotificationStream,
  }) => MaterialApp(
    home: MessagesScreen(
      currentUid: 'me',
      repository: repository,
      conversationNotificationStream: conversationNotificationStream,
    ),
  );

  Map<String, dynamic> notification({
    bool isRead = false,
    int createdAt = 1,
    String actorUid = 'friend',
  }) => {
    'isRead': isRead,
    'createdAt': DateTime.fromMicrosecondsSinceEpoch(createdAt),
    'actorUid': actorUid,
    'recipientUid': 'me',
    'conversationId': 'match-id',
  };

  Widget conversation(
    FakeMessagingRepository repository,
    Stream<Map<String, dynamic>?> stream,
  ) => MaterialApp(
    home: ConversationScreen(
      conversationId: 'match-id',
      currentUid: 'me',
      title: 'Club X',
      repository: repository,
      notificationStream: (_, _) => stream,
    ),
  );

  testWidgets(
    'conversation list shows direct/match identity, previews, and unread badge',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MessagesScreen(
            currentUid: 'me',
            repository: FakeMessagingRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Club X'), findsOneWidget);
      expect(find.text('Thursday?'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    },
  );

  testWidgets('inbox listener starts once and initial snapshot is baseline', (
    tester,
  ) async {
    final repository = FakeMessagingRepository();
    await tester.pumpWidget(inbox(repository));
    await tester.pumpAndSettle();
    expect(repository.inboxListens, 1);
    expect(repository.conversationLoads, 1);

    repository.emitInboxVersion('baseline');
    await tester.pumpAndSettle();
    expect(repository.conversationLoads, 1);

    await tester.pumpWidget(inbox(repository));
    await tester.pumpAndSettle();
    expect(repository.inboxListens, 1);
  });

  testWidgets('incoming notification updates preview unread and ordering', (
    tester,
  ) async {
    const other = ConversationSummary(
      id: 'direct-id',
      type: 'direct',
      otherUid: 'friend',
      preview: 'Other conversation',
    );
    final repository = FakeMessagingRepository(
      conversationResponses: [
        ConversationsPage(const [other, oldMatch]),
        ConversationsPage(const [updatedMatch, other]),
      ],
    );
    await tester.pumpWidget(inbox(repository));
    await tester.pumpAndSettle();
    repository.emitInboxVersion('message:1');
    await tester.pumpAndSettle();
    repository.emitInboxVersion('message:2');
    await tester.pumpAndSettle();

    expect(find.text('live test 2'), findsNothing);
    expect(find.text('inbox live test'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    final matchTop = tester
        .getTopLeft(find.byKey(const Key('conversation-match-id')))
        .dy;
    final directTop = tester
        .getTopLeft(find.byKey(const Key('conversation-direct-id')))
        .dy;
    expect(matchTop, lessThan(directTop));
    expect(repository.conversationLoads, 2);
  });

  testWidgets('deterministic notification modification triggers reload', (
    tester,
  ) async {
    final repository = FakeMessagingRepository(
      conversationResponses: [
        ConversationsPage(const [oldMatch]),
        ConversationsPage(const [updatedMatch]),
      ],
    );
    await tester.pumpWidget(inbox(repository));
    await tester.pumpAndSettle();
    repository.emitInboxVersion('same-document:1');
    await tester.pumpAndSettle();
    repository.emitInboxVersion('same-document:2');
    await tester.pumpAndSettle();
    expect(find.text('inbox live test'), findsOneWidget);
  });

  testWidgets('mark-read-only notification change does not reload', (
    tester,
  ) async {
    final repository = FakeMessagingRepository();
    await tester.pumpWidget(inbox(repository));
    await tester.pumpAndSettle();
    repository.emitInboxVersion('message-created-at');
    await tester.pumpAndSettle();
    repository.emitInboxVersion('message-created-at');
    await tester.pumpAndSettle();
    expect(repository.conversationLoads, 1);
  });

  testWidgets('inbox invalidations coalesce with one follow-up refresh', (
    tester,
  ) async {
    final active = Completer<ConversationsPage>();
    final followUp = Completer<ConversationsPage>();
    final repository = FakeMessagingRepository(
      conversationResponses: [
        ConversationsPage(const [oldMatch]),
        active.future,
        followUp.future,
      ],
    );
    await tester.pumpWidget(inbox(repository));
    await tester.pumpAndSettle();
    repository.emitInboxVersion('baseline');
    await tester.pump();
    repository.emitInboxVersion('change-1');
    await tester.pump();
    repository.emitInboxVersion('change-2');
    repository.emitInboxVersion('change-3');
    await tester.pump();
    expect(repository.conversationLoads, 2);

    active.complete(ConversationsPage(const [updatedMatch]));
    await tester.pump();
    await tester.pump();
    expect(repository.conversationLoads, 3);
    followUp.complete(ConversationsPage(const [updatedMatch]));
    await tester.pumpAndSettle();
    expect(repository.conversationLoads, 3);
  });

  testWidgets(
    'inbox listener cancels and is not duplicated after chat return',
    (tester) async {
      final repository = FakeMessagingRepository(
        conversationResponses: [
          ConversationsPage(const [oldMatch]),
          ConversationsPage(const [oldMatch]),
        ],
      );
      final conversationEvents =
          StreamController<Map<String, dynamic>?>.broadcast();
      await tester.pumpWidget(
        inbox(
          repository,
          conversationNotificationStream: (_, _) => conversationEvents.stream,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conversation-match-id')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(repository.inboxListens, 1);
      expect(repository.conversationLoads, 2);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      expect(repository.inboxCancellations, 1);
      unawaited(conversationEvents.close());
    },
  );

  testWidgets('invalidation resets pagination and Load older still works', (
    tester,
  ) async {
    final repository = FakeMessagingRepository(
      conversationResponses: [
        ConversationsPage(const [oldMatch], cursor: 'page-one', hasMore: true),
        ConversationsPage(const [
          ConversationSummary(
            id: 'older',
            type: 'match',
            matchId: 'older-match',
            preview: 'Older',
          ),
        ]),
        ConversationsPage(const [updatedMatch]),
      ],
    );
    await tester.pumpWidget(inbox(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('load-older-conversations')));
    await tester.pumpAndSettle();
    expect(find.text('Older'), findsOneWidget);
    repository.emitInboxVersion('baseline');
    await tester.pumpAndSettle();
    repository.emitInboxVersion('new-message');
    await tester.pumpAndSettle();
    expect(repository.conversationBefores, [null, 'page-one', null]);
    expect(find.text('Older'), findsNothing);
    expect(find.text('inbox live test'), findsOneWidget);
  });

  testWidgets('listener and reload failures preserve existing inbox rows', (
    tester,
  ) async {
    final repository = FakeMessagingRepository(
      conversationResponses: [
        ConversationsPage(const [oldMatch]),
        Exception('refresh'),
      ],
    );
    await tester.pumpWidget(inbox(repository));
    await tester.pumpAndSettle();
    repository.failInboxListener();
    await tester.pump();
    expect(find.text('live test 2'), findsOneWidget);
    repository.emitInboxVersion('baseline');
    await tester.pumpAndSettle();
    repository.emitInboxVersion('new-message');
    await tester.pumpAndSettle();
    expect(find.text('live test 2'), findsOneWidget);
  });

  testWidgets('read-only conversation disables composer', (tester) async {
    final notifications = StreamController<Map<String, dynamic>?>();
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationScreen(
          conversationId: 'match-id',
          currentUid: 'me',
          title: 'Club X',
          repository: FakeMessagingRepository(readOnly: true),
          notificationStream: (_, _) => notifications.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('message-composer-disabled')), findsOneWidget);
    expect(find.byKey(const Key('message-composer')), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
    await notifications.close();
  });

  testWidgets('new unread remote notification reloads messages once', (
    tester,
  ) async {
    final repository = FakeMessagingRepository();
    final notifications = StreamController<Map<String, dynamic>?>();
    await tester.pumpWidget(conversation(repository, notifications.stream));
    await tester.pumpAndSettle();
    expect(repository.messageLoads, 1);

    notifications.add(notification());
    await tester.pumpAndSettle();
    expect(repository.messageLoads, 2);

    notifications.add(notification());
    await tester.pumpAndSettle();
    expect(repository.messageLoads, 2);
    await notifications.close();
  });

  testWidgets('read and mark-read notification updates do not reload', (
    tester,
  ) async {
    final repository = FakeMessagingRepository();
    final notifications = StreamController<Map<String, dynamic>?>();
    repository.onMarkRead = () => notifications.add(notification(isRead: true));
    await tester.pumpWidget(conversation(repository, notifications.stream));
    await tester.pumpAndSettle();
    expect(repository.messageLoads, 1);

    notifications.add(notification(createdAt: 2));
    await tester.pumpAndSettle();
    expect(repository.messageLoads, 2);

    notifications.add(notification(isRead: true, createdAt: 2));
    await tester.pumpAndSettle();
    expect(repository.messageLoads, 2);
    await notifications.close();
  });

  testWidgets('listener starts once and is cancelled on dispose', (
    tester,
  ) async {
    var listens = 0;
    var cancellations = 0;
    final notifications = StreamController<Map<String, dynamic>?>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancellations++,
    );
    final repository = FakeMessagingRepository();
    await tester.pumpWidget(conversation(repository, notifications.stream));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(listens, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(cancellations, 1);
    await notifications.close();
  });

  testWidgets('manual refresh and send retain existing behavior', (
    tester,
  ) async {
    final repository = FakeMessagingRepository();
    final notifications = StreamController<Map<String, dynamic>?>();
    await tester.pumpWidget(conversation(repository, notifications.stream));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('refresh-conversation')));
    await tester.pumpAndSettle();
    expect(repository.messageLoads, 2);

    await tester.enterText(
      find.byKey(const Key('message-composer')),
      'Still callable-mediated',
    );
    await tester.tap(find.byKey(const Key('send-message')));
    await tester.pumpAndSettle();
    expect(repository.sends, 1);
    expect(repository.sentText, 'Still callable-mediated');
    expect(repository.messageLoads, 3);
    await notifications.close();
  });
}
