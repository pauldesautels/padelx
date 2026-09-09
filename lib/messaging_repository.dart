import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'messaging.dart';

class ConversationsPage {
  final List<ConversationSummary> conversations;
  final String? cursor;
  final bool hasMore;
  const ConversationsPage(
    this.conversations, {
    this.cursor,
    this.hasMore = false,
  });
}

class MessagesPage {
  final List<ChatMessage> messages;
  final String? cursor;
  final bool hasMore;
  final bool canSend;
  final String? disabledReason;
  const MessagesPage(
    this.messages, {
    this.cursor,
    this.hasMore = false,
    this.canSend = true,
    this.disabledReason,
  });
}

abstract class MessagingRepository {
  Stream<String> watchInboxInvalidations(String currentUid);
  Future<String> ensureDirect(String otherUid);
  Future<({String conversationId, bool canSend, String? disabledReason})>
  ensureMatch(String matchId);
  Future<ConversationsPage> conversations({String? before, int limit = 20});
  Future<MessagesPage> messages(
    String conversationId, {
    String? before,
    int limit = 40,
  });
  Future<void> send(String conversationId, String text, String requestId);
  Future<void> markRead(String conversationId);
  Future<Map<String, String>> directNames(Iterable<String> uids);
  Future<Map<String, String>> matchNames(Iterable<String> ids);
}

class FirebaseMessagingRepository implements MessagingRepository {
  final FirebaseFunctions functions;
  final FirebaseFirestore firestore;
  FirebaseMessagingRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : functions = functions ?? FirebaseFunctions.instance,
       firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<dynamic, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async => Map<dynamic, dynamic>.from(
    (await functions.httpsCallable(name).call(data)).data as Map,
  );

  String _notificationVersion(Object? value) {
    if (value is Timestamp) return '${value.seconds}:${value.nanoseconds}';
    if (value is DateTime) return value.microsecondsSinceEpoch.toString();
    return value?.toString() ?? '';
  }

  @override
  Stream<String> watchInboxInvalidations(String currentUid) => firestore
      .collection('notifications')
      .where('recipientUid', isEqualTo: currentUid)
      .snapshots()
      .map((snapshot) {
        final versions =
            snapshot.docs
                .where((doc) {
                  final type = doc.data()['type'];
                  return type == 'direct_message' || type == 'match_message';
                })
                .map(
                  (doc) =>
                      '${doc.id}:${_notificationVersion(doc.data()['createdAt'])}',
                )
                .toList()
              ..sort();
        return versions.join('|');
      });

  @override
  Future<String> ensureDirect(String otherUid) async => (await _call(
    'ensureDirectConversation',
    {'otherUid': otherUid},
  ))['conversationId'].toString();

  @override
  Future<({String conversationId, bool canSend, String? disabledReason})>
  ensureMatch(String matchId) async {
    final data = await _call('ensureMatchConversation', {'matchId': matchId});
    return (
      conversationId: data['conversationId'].toString(),
      canSend: data['canSend'] != false,
      disabledReason: data['disabledReason']?.toString(),
    );
  }

  @override
  Future<ConversationsPage> conversations({
    String? before,
    int limit = 20,
  }) async {
    final data = await _call('listConversations', {
      'limit': limit,
      'before': ?before,
    });
    return ConversationsPage(
      (data['conversations'] as List? ?? const [])
          .map(
            (item) => ConversationSummary.fromMap(
              Map<dynamic, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      cursor: data['nextCursor']?.toString(),
      hasMore: data['hasMore'] == true,
    );
  }

  @override
  Future<MessagesPage> messages(
    String conversationId, {
    String? before,
    int limit = 40,
  }) async {
    final data = await _call('listMessages', {
      'conversationId': conversationId,
      'limit': limit,
      'before': ?before,
    });
    return MessagesPage(
      (data['messages'] as List? ?? const [])
          .map(
            (item) =>
                ChatMessage.fromMap(Map<dynamic, dynamic>.from(item as Map)),
          )
          .toList(),
      cursor: data['nextCursor']?.toString(),
      hasMore: data['hasMore'] == true,
      canSend: data['canSend'] != false,
      disabledReason: data['disabledReason']?.toString(),
    );
  }

  @override
  Future<void> send(
    String conversationId,
    String text,
    String requestId,
  ) async {
    await _call('sendMessage', {
      'conversationId': conversationId,
      'text': text,
      'requestId': requestId,
    });
  }

  @override
  Future<void> markRead(String conversationId) async {
    await _call('markConversationRead', {'conversationId': conversationId});
  }

  @override
  Future<Map<String, String>> directNames(Iterable<String> uids) async {
    final ids = uids.where((id) => id.isNotEmpty).toSet().toList();
    final names = <String, String>{};
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      if (chunk.isEmpty) continue;
      final docs = await firestore
          .collection('publicProfiles')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in docs.docs) {
        names[doc.id] = doc.data()['displayName']?.toString() ?? 'Player';
      }
    }
    return names;
  }

  Future<Map<String, int>> directAvatarVersions(Iterable<String> uids) async {
    final ids = uids.where((id) => id.isNotEmpty).toSet().toList();
    final versions = <String, int>{};
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      if (chunk.isEmpty) continue;
      final docs = await firestore
          .collection('publicProfiles')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in docs.docs) {
        final value = doc.data()['avatarVersion'];
        versions[doc.id] = value is num ? value.toInt() : 0;
      }
    }
    return versions;
  }

  @override
  Future<Map<String, String>> matchNames(Iterable<String> ids) async {
    final values = ids.where((id) => id.isNotEmpty).toSet().toList();
    final names = <String, String>{};
    for (var i = 0; i < values.length; i += 30) {
      final chunk = values.sublist(i, (i + 30).clamp(0, values.length));
      if (chunk.isEmpty) continue;
      final docs = await firestore
          .collection('matches')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in docs.docs) {
        names[doc.id] = doc.data()['club']?.toString() ?? 'Match';
      }
    }
    return names;
  }
}
