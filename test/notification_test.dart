import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/main.dart';

AppNotification notification({
  required String id,
  DateTime? createdAt,
  bool read = false,
  AppNotificationType type = AppNotificationType.joinRequest,
  String eventId = 'cycle-1',
  String? message,
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
  message: message ?? 'Historical activity',
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

  test('friendly timestamps cover today, yesterday, week, and older', () {
    expect(relativeNotificationTime(now, now), '12:00 PM');
    expect(
      relativeNotificationTime(now.subtract(const Duration(minutes: 15)), now),
      '11:45 AM',
    );
    expect(
      relativeNotificationTime(now.subtract(const Duration(hours: 3)), now),
      '9:00 AM',
    );
    expect(
      relativeNotificationTime(now.subtract(const Duration(hours: 25)), now),
      'Yesterday',
    );
    expect(
      relativeNotificationTime(now.subtract(const Duration(days: 3)), now),
      'Sun',
    );
    expect(relativeNotificationTime(DateTime(2026, 8, 4), now), 'Aug 4');
    expect(relativeNotificationTime(DateTime(2025, 8, 4), now), 'Aug 4, 2025');
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
    expect(notificationReadUpdate(), {'isRead': true});
    expect(notificationReadUpdate().containsKey('createdAt'), isFalse);
  });

  test('notification serialization accepts current and malformed data', () {
    final current = AppNotification.fromMap('one', {
      'type': 'join_approved',
      'recipientUid': 'player',
      'matchId': 'match-1',
      'matchClubName': 'Roma Padel',
      'message': 'Approved',
      'isRead': true,
      'createdAt': DateTime.utc(2026, 8, 26),
    });
    expect(current.type, AppNotificationType.joinApproved);
    expect(current.matchClubName, 'Roma Padel');
    expect(current.read, isTrue);

    final malformed = AppNotification.fromMap('legacy', {
      'type': 42,
      'message': null,
      'isRead': 'not-a-bool',
    });
    expect(malformed.id, 'legacy');
    expect(malformed.type, AppNotificationType.unknown);
    expect(malformed.message, '');
    expect(malformed.read, isFalse);
  });

  test('notification match navigation finds a match or returns null', () {
    final match = Match(
      id: 'match',
      title: 'Friday match',
      club: 'Roma Padel',
      level: 'Level 3',
      spotsLeft: 2,
      creatorUid: 'organizer',
      creatorEmail: 'organizer@example.com',
      players: const [],
    );
    expect(matchForNotification(notification(id: 'one'), [match]), same(match));
    expect(matchForNotification(notification(id: 'one'), const []), isNull);
  });

  testWidgets('mark all appears only for unread notifications', (tester) async {
    var invoked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: [notification(id: 'one')],
            isLoading: false,
            error: false,
            onMarkRead: (_) {},
            onOpen: (_) {},
            onMarkAllRead: () async {
              invoked = true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mark all as read'));
    await tester.pump();
    expect(invoked, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: [notification(id: 'one', read: true)],
            isLoading: false,
            error: false,
            onMarkRead: (_) {},
            onOpen: (_) {},
            onMarkAllRead: () async {},
          ),
        ),
      ),
    );
    expect(find.text('Mark all as read'), findsNothing);
  });

  testWidgets('mark all prevents repeated actions while processing', (
    tester,
  ) async {
    final completion = Completer<void>();
    var invocations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: [notification(id: 'one')],
            isLoading: false,
            error: false,
            onMarkRead: (_) {},
            onOpen: (_) {},
            onMarkAllRead: () {
              invocations++;
              return completion.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mark all as read'));
    await tester.pump();
    expect(invocations, 1);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('mark-all-notifications-read')),
          )
          .onPressed,
      isNull,
    );
    completion.complete();
    await tester.pump();
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
    expect(find.text('11:58 AM'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(
      tester.widget<Card>(find.byType(Card)).color,
      const Color(0xFF1D3027),
    );
    expect(find.byTooltip('Mark as read'), findsOneWidget);
    expect(find.text('Mark read'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-indicator')), findsOneWidget);
  });

  testWidgets('read card remains legible without unread controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationCard(
            notification: notification(id: 'read', read: true),
            now: now,
            onMarkRead: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Historical activity'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-indicator')), findsNothing);
    expect(find.byTooltip('Mark as read'), findsNothing);
    expect(
      tester.widget<Card>(find.byType(Card)).color,
      const Color(0xFF18211D),
    );
  });

  testWidgets('all notification event types use historical titles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: [
              notification(id: 'request'),
              notification(
                id: 'approved',
                type: AppNotificationType.joinApproved,
              ),
              notification(
                id: 'declined',
                type: AppNotificationType.joinDeclined,
              ),
            ],
            isLoading: false,
            error: false,
            onMarkRead: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('New join request'), findsOneWidget);
    expect(find.text('Request approved'), findsOneWidget);
    expect(find.text('Request declined'), findsOneWidget);
  });

  testWidgets('notification row opens the selected notification', (
    tester,
  ) async {
    AppNotification? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: [notification(id: 'open-me')],
            isLoading: false,
            error: false,
            onMarkRead: (_) {},
            onOpen: (item) => opened = item,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('notification-open-me')));
    expect(opened?.id, 'open-me');
  });

  testWidgets('loading and retryable error states are friendly', (
    tester,
  ) async {
    Widget screen({
      required bool loading,
      required bool error,
      VoidCallback? retry,
    }) => MaterialApp(
      home: Scaffold(
        body: NotificationsTab(
          notifications: const [],
          isLoading: loading,
          error: error,
          onMarkRead: (_) {},
          onOpen: (_) {},
          onRetry: retry,
        ),
      ),
    );
    await tester.pumpWidget(screen(loading: true, error: false));
    expect(find.bySemanticsLabel('Loading notifications'), findsOneWidget);
    var retried = false;
    await tester.pumpWidget(
      screen(loading: false, error: true, retry: () => retried = true),
    );
    expect(
      find.text('Notifications are unavailable right now.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('long content fits a 320px layout without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: [
              notification(
                id: 'long',
                message:
                    'Alexandria Montgomery requested to join your match at The Extremely Long International Padel Club Name.',
              ),
            ],
            isLoading: false,
            error: false,
            onMarkRead: (_) {},
            onOpen: (_) {},
            onMarkAllRead: () async {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Alexandria Montgomery'), findsOneWidget);
  });

  testWidgets('all known types and unknown use safe icon presentation', (
    tester,
  ) async {
    for (final type in AppNotificationType.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              notification: notification(id: type.name, type: type),
              now: now,
              onMarkRead: (_) {},
              onOpen: (_) {},
            ),
          ),
        ),
      );
      expect(
        find.byKey(ValueKey('notification-type-${type.name}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('join request status renders as a compact chip', (tester) async {
    for (final status in const [
      'Pending',
      'Approved',
      'Declined',
      'No longer active',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              notification: notification(id: status),
              now: now,
              onMarkRead: (_) {},
              onOpen: (_) {},
              requestStream: Stream.value(
                status == 'No longer active'
                    ? null
                    : {'eventId': 'cycle-1', 'status': status.toLowerCase()},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(ValueKey('notification-status-$status')),
        findsOneWidget,
      );
    }
  });

  testWidgets('later listener failure preserves existing notifications', (
    tester,
  ) async {
    Widget screen(List<AppNotification> items, {bool error = false}) =>
        MaterialApp(
          home: Scaffold(
            body: NotificationsTab(
              notifications: items,
              isLoading: false,
              error: error,
              onMarkRead: (_) {},
              onOpen: (_) {},
            ),
          ),
        );
    await tester.pumpWidget(screen([notification(id: 'kept')]));
    expect(find.byKey(const ValueKey('notification-kept')), findsOneWidget);
    await tester.pumpWidget(screen(const [], error: true));
    expect(find.byKey(const ValueKey('notification-kept')), findsOneWidget);
    expect(find.text('Notifications are unavailable right now.'), findsNothing);
  });

  testWidgets('mark-all failure is safely reported', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: [notification(id: 'one')],
            isLoading: false,
            error: false,
            onMarkRead: (_) {},
            onOpen: (_) {},
            onMarkAllRead: () async => throw Exception('private details'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(find.text('Could not mark notifications as read.'), findsOneWidget);
    expect(find.textContaining('private details'), findsNothing);
  });

  testWidgets('mark-read failure is safely reported', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: [notification(id: 'one')],
            isLoading: false,
            error: false,
            onMarkRead: (_) => throw Exception('private details'),
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mark read'));
    await tester.pumpAndSettle();
    expect(find.text('Could not mark notification as read.'), findsOneWidget);
    expect(find.textContaining('private details'), findsNothing);
  });

  testWidgets('notification exposes coherent unread semantics at large text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: NotificationCard(
              notification: notification(id: 'semantic', createdAt: now),
              now: now,
              onMarkRead: (_) {},
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );
    final node = tester.getSemantics(
      find.byKey(const ValueKey('notification-semantic')),
    );
    expect(node.label, contains('Unread'));
    expect(node.label, contains('Historical activity'));
    expect(node.label, contains('12:00 PM'));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
