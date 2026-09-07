import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/conversation_screen.dart';
import 'package:padelx/messages_screen.dart';
import 'package:padelx/messaging.dart';
import 'package:padelx/messaging_repository.dart';

class FakeMessagingRepository implements MessagingRepository {
  bool readOnly;
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
  }) async => MessagesPage(
    [const ChatMessage(id: 'one', senderUid: 'friend', text: 'Hello')],
    canSend: !readOnly,
    disabledReason: readOnly ? 'This conversation is read-only.' : null,
  );
  @override
  Future<void> markRead(String conversationId) async {}
  @override
  Future<void> send(
    String conversationId,
    String text,
    String requestId,
  ) async {}
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
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationScreen(
          conversationId: 'match-id',
          currentUid: 'me',
          title: 'Club X',
          repository: FakeMessagingRepository(readOnly: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('message-composer-disabled')), findsOneWidget);
    expect(find.byKey(const Key('message-composer')), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
  });
}
