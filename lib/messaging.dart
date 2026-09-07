class ConversationSummary {
  final String id;
  final String type;
  final String? otherUid;
  final String? matchId;
  final String preview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool canSend;
  final String? disabledReason;

  const ConversationSummary({
    required this.id,
    required this.type,
    this.otherUid,
    this.matchId,
    this.preview = '',
    this.lastMessageAt,
    this.unreadCount = 0,
    this.canSend = true,
    this.disabledReason,
  });

  factory ConversationSummary.fromMap(Map<dynamic, dynamic> data) =>
      ConversationSummary(
        id: data['id']?.toString() ?? data['conversationId']?.toString() ?? '',
        type: data['type']?.toString() ?? '',
        otherUid: data['otherUid']?.toString(),
        matchId: data['matchId']?.toString(),
        preview: data['lastMessagePreview']?.toString() ?? '',
        lastMessageAt: _messageDate(data['lastMessageAt']),
        unreadCount: data['unreadCount'] is num
            ? (data['unreadCount'] as num).toInt()
            : 0,
        canSend: data['canSend'] != false,
        disabledReason: data['disabledReason']?.toString(),
      );
}

class ChatMessage {
  final String id;
  final String senderUid;
  final String text;
  final DateTime? createdAt;
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    this.createdAt,
  });
  factory ChatMessage.fromMap(Map<dynamic, dynamic> data) => ChatMessage(
    id: data['id']?.toString() ?? '',
    senderUid: data['senderUid']?.toString() ?? '',
    text: data['text']?.toString() ?? '',
    createdAt: _messageDate(data['createdAt']),
  );
}

DateTime? _messageDate(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    return (value as dynamic)?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}

String messagingTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
  }
  return '${local.month}/${local.day}/${local.year}';
}
