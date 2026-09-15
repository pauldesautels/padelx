import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

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

String _localeName(Locale? locale) => locale == null
    ? 'en_US'
    : '${locale.languageCode}_${locale.countryCode ?? (locale.languageCode == 'es' ? 'MX' : 'US')}';

bool _isSpanish(Locale? locale) => locale?.languageCode == 'es';

String _englishClock(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour < 12 ? 'AM' : 'PM'}';
}

String messagingTime(DateTime? value, {Locale? locale}) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return _isSpanish(locale)
        ? DateFormat.jm(_localeName(locale)).format(local)
        : _englishClock(local);
  }
  return DateFormat.yMd(_localeName(locale)).format(local);
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

String messagingDateSeparator(
  DateTime? value, {
  DateTime? now,
  Locale? locale,
  String todayLabel = 'Today',
  String yesterdayLabel = 'Yesterday',
}) {
  if (value == null) return '';
  final local = value.toLocal();
  final today = _localDate(now ?? DateTime.now());
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return todayLabel;
  if (difference == 1) return yesterdayLabel;
  return local.year == today.year
      ? DateFormat(
          _isSpanish(locale) ? 'd MMMM' : 'MMMM d',
          _localeName(locale),
        ).format(local)
      : DateFormat(
          _isSpanish(locale) ? 'd MMM y' : 'MMMM d, y',
          _localeName(locale),
        ).format(local);
}

String messagingInboxTime(
  DateTime? value, {
  DateTime? now,
  Locale? locale,
  String yesterdayLabel = 'Yesterday',
}) {
  if (value == null) return '';
  final local = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) {
    return _isSpanish(locale)
        ? DateFormat.jm(_localeName(locale)).format(local)
        : _englishClock(local);
  }
  if (difference == 1) return yesterdayLabel;
  if (difference > 1 && difference < 7) {
    return DateFormat.E(_localeName(locale)).format(local);
  }
  return local.year == current.year
      ? DateFormat.MMMd(_localeName(locale)).format(local)
      : DateFormat.yMMMd(_localeName(locale)).format(local);
}
