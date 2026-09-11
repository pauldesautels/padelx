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

class MessagingIdentity {
  final String uid;
  final String displayName;
  final int avatarVersion;

  const MessagingIdentity({
    required this.uid,
    required this.displayName,
    this.avatarVersion = 0,
  });
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
    return _clockTime(local);
  }
  return '${local.month}/${local.day}/${local.year}';
}

bool messagingSameLocalDay(DateTime? left, DateTime? right) {
  if (left == null || right == null) return left == right;
  final a = left.toLocal();
  final b = right.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _localDate(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String messagingDateSeparator(DateTime? value, {DateTime? now}) {
  if (value == null) return '';
  final local = value.toLocal();
  final today = _localDate(now ?? DateTime.now());
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return '${_monthNames[local.month - 1]} ${local.day}'
      '${local.year == today.year ? '' : ', ${local.year}'}';
}

String messagingInboxTime(DateTime? value, {DateTime? now}) {
  if (value == null) return '';
  final local = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return _clockTime(local);
  if (difference == 1) return 'Yesterday';
  if (difference > 1 && difference < 7) return _weekdayNames[local.weekday - 1];
  final date = '${_shortMonthNames[local.month - 1]} ${local.day}';
  return local.year == current.year ? date : '$date, ${local.year}';
}

String _clockTime(DateTime local) {
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
}

const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _shortMonthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdayNames = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
