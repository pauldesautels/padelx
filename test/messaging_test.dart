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
  FakeMessagingRepository({this.readOnly = false});
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
  }) async => ConversationsPage([
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
