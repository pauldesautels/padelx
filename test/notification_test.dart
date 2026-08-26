import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/main.dart';

AppNotification notification({
  required String id,
  DateTime? createdAt,
  bool read = false,
  AppNotificationType type = AppNotificationType.joinRequest,
  String eventId = 'cycle-1',
}) => AppNotification(
  id: id,
  type: type,
  recipientUid: 'recipient',
  matchId: 'match',
  title: type == AppNotificationType.joinApproved
      ? 'Request approved'
      : type == AppNotificationType.joinDeclined
      ? 'Request declined'
      : 'New join request',
  message: 'Historical activity',
  read: read,
  createdAt: createdAt,
  eventId: eventId,
  actorUid: 'player',
  actorDisplayName: 'Ana',
);

void main() {
  final now = DateTime(2026, 8, 26, 12);

  test('notifications sort newest first with null timestamps last', () {
    final result = sortedNotifications([
      notification(id: 'old', createdAt: now.subtract(const Duration(days: 1))),
      notification(id: 'legacy'),
      notification(id: 'new', createdAt: now),
    ]);
    expect(result.map((item) => item.id), ['new', 'old', 'legacy']);
  });

  test('relative timestamps cover current, minutes, hours, and days', () {
    expect(relativeNotificationTime(now, now), 'Just now');
    expect(
      relativeNotificationTime(now.subtract(const Duration(minutes: 15)), now),
      '15 min ago',
    );
    expect(
      relativeNotificationTime(now.subtract(const Duration(hours: 3)), now),
      '3 hrs ago',
    );
    expect(
      relativeNotificationTime(now.subtract(const Duration(hours: 25)), now),
      'Yesterday',
    );
    expect(
      relativeNotificationTime(now.subtract(const Duration(days: 3)), now),
      '3 days ago',
    );
    expect(relativeNotificationTime(null, now), 'Time unavailable');
  });

  test('join request status requires the same event cycle', () {
    final item = notification(id: 'request');
    expect(
      joinRequestNotificationStatus(item, {
        'eventId': 'cycle-1',
        'status': 'pending',
      }),
      'Pending',
    );
    expect(
      joinRequestNotificationStatus(item, {
        'eventId': 'cycle-1',
        'status': 'approved',
      }),
      'Approved',
    );
    expect(
      joinRequestNotificationStatus(item, {
        'eventId': 'cycle-1',
        'status': 'declined',
      }),
      'Declined',
    );
    expect(
      joinRequestNotificationStatus(item, {
        'eventId': 'cycle-2',
        'status': 'pending',
      }),
      'No longer active',
    );
  });

  test('legacy request notification does not invent status', () {
    final legacy = notification(id: 'legacy', eventId: '');
    expect(
      joinRequestNotificationStatus(legacy, {'status': 'pending'}),
      isNull,
    );
  });

  test('leave and rejoin cycles create distinct deterministic documents', () {
    expect(
      notificationDocumentId(
        AppNotificationType.joinRequest,
        'match',
        'cycle-1',
      ),
      isNot(
        notificationDocumentId(
          AppNotificationType.joinRequest,
          'match',
          'cycle-2',
        ),
      ),
    );
  });

  test('requester review notifications remain historical events', () {
    expect(
      joinRequestNotificationStatus(
        notification(id: 'approved', type: AppNotificationType.joinApproved),
        {'eventId': 'cycle-2', 'status': 'pending'},
      ),
      isNull,
    );
    expect(
      joinRequestNotificationStatus(
        notification(id: 'declined', type: AppNotificationType.joinDeclined),
        {'eventId': 'cycle-2', 'status': 'pending'},
      ),
      isNull,
    );
  });

  test('mark-read mutation cannot alter createdAt', () {
    expect(notificationReadUpdate(), {'read': true});
    expect(notificationReadUpdate().containsKey('createdAt'), isFalse);
  });

  testWidgets('card shows relative time, status, and unread styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationCard(
            notification: notification(
              id: 'one',
              createdAt: now.subtract(const Duration(minutes: 2)),
            ),
            now: now,
            onMarkRead: (_) {},
            onOpen: (_) {},
            requestStream: Stream.value({
              'eventId': 'cycle-1',
              'status': 'pending',
            }),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('2 min ago · Pending'), findsOneWidget);
    expect(
      tester.widget<Card>(find.byType(Card)).color,
      const Color(0xFF203A2D),
    );
    expect(find.byTooltip('Mark as read'), findsOneWidget);
  });
}
