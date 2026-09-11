import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/push_notifications.dart';
import 'package:padelx/settings_screen.dart';

class _Preferences implements NotificationPreferencesRepository {
  NotificationPreferences value;
  Completer<NotificationPreferences>? nextLoad;
  Object? loadError;
  final StreamController<NotificationPreferences> controller =
      StreamController<NotificationPreferences>.broadcast();
  int saves = 0;
  _Preferences([this.value = const NotificationPreferences()]);
  @override
  Future<NotificationPreferences> load(String uid) async {
    if (loadError != null) throw loadError!;
    final delayed = nextLoad;
    nextLoad = null;
    return delayed == null ? value : delayed.future;
  }

  @override
  Future<void> save(String uid, NotificationPreferences preferences) async {
    value = preferences;
    saves++;
    controller.add(value);
  }

  @override
  Stream<NotificationPreferences> watch(String uid) async* {
    yield value;
    yield* controller.stream;
  }
}

class _Messaging implements PushMessagingGateway {
  PushPermissionState permission;
  String? currentToken = 'fcm-token-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
  int requests = 0;
  int tokenReads = 0;
  final StreamController<String> refresh = StreamController<String>.broadcast();
  _Messaging({this.permission = PushPermissionState.notDetermined});
  @override
  Future<PushPermissionState> permissionState() async => permission;
  @override
  Future<PushPermissionState> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<String?> token() async {
    tokenReads++;
    return currentToken;
  }

  @override
  Stream<String> get tokenRefreshes => refresh.stream;
}

class _Devices implements PushDeviceRepository {
  final List<String> registered = [];
  final List<String> unregistered = [];
  bool failUnregister = false;
  @override
  Future<void> register(String token) async => registered.add(token);
  @override
  Future<void> unregister(String token) async {
    unregistered.add(token);
    if (failUnregister) throw StateError('offline');
  }
}

class _UnsupportedMessaging implements PushMessagingGateway {
  int requests = 0;
  int tokenReads = 0;

  @override
  Future<PushPermissionState> permissionState() async =>
      PushPermissionState.unsupported;
  @override
  Future<PushPermissionState> requestPermission() async {
    requests++;
    return PushPermissionState.unsupported;
  }

  @override
  Future<String?> token() async {
    tokenReads++;
    return null;
  }

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

PushNotificationService _service(
  PushMessagingGateway messaging,
  _Devices devices,
  _Preferences preferences,
) => PushNotificationService(
  messaging: messaging,
  devices: devices,
  preferences: preferences,
);

void main() {
  test(
    'build capability keeps default device-test off and staging available',
    () {
      expect(
        pushCapabilityAvailable(
          isWeb: false,
          platform: TargetPlatform.iOS,
          iosDeviceTest: true,
        ),
        false,
      );
      expect(
        pushCapabilityAvailable(
          isWeb: false,
          platform: TargetPlatform.iOS,
          iosDeviceTest: false,
        ),
        true,
      );
      expect(
        pushCapabilityAvailable(
          isWeb: false,
          platform: TargetPlatform.android,
          iosDeviceTest: false,
        ),
        true,
      );
    },
  );

  test('missing preference document uses opt-out with enabled categories', () {
    final value = NotificationPreferences.fromMap(null);
    expect(value.pushEnabled, false);
    expect(value.matchMessages, true);
    expect(value.joinRequests, true);
    expect(value.friendRequests, true);
    expect(value.friendAccepted, true);
    expect(value.matchUpdates, true);
    expect(value.playAgain, true);
  });

  test('startup synchronization logs only safe Firebase diagnostics', () async {
    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);
    final preferences = _Preferences()
      ..loadError = FirebaseException(
        plugin: 'firebase_firestore',
        code: 'permission-denied',
        message: 'private@example.com token-secret',
      );

    await _service(
      _UnsupportedMessaging(),
      _Devices(),
      preferences,
    ).startForUser('alice');

    expect(
      logs,
      contains(
        'Push registration synchronization failed '
        '[firebase_firestore/permission-denied; authorization-or-app-check].',
      ),
    );
    expect(logs.join(' '), isNot(contains('private@example.com')));
    expect(logs.join(' '), isNot(contains('token-secret')));
  });

  test('denied permission never registers or enables push', () async {
    final messaging = _Messaging(permission: PushPermissionState.denied);
    final devices = _Devices();
    final preferences = _Preferences();
    final result = await _service(
      messaging,
      devices,
      preferences,
    ).enable('alice');
    expect(result, PushPermissionState.denied);
    expect(messaging.requests, 1);
    expect(devices.registered, isEmpty);
    expect(preferences.value.pushEnabled, false);
  });

  test('approval retrieves and registers token before enabling push', () async {
    final messaging = _Messaging(permission: PushPermissionState.allowed);
    final devices = _Devices();
    final preferences = _Preferences();
    await _service(messaging, devices, preferences).enable('alice');
    expect(devices.registered, [messaging.currentToken]);
    expect(preferences.value.pushEnabled, true);
  });

  test('disable persists opt-out and tolerates unregister failure', () async {
    final messaging = _Messaging(permission: PushPermissionState.allowed);
    final devices = _Devices()..failUnregister = true;
    final preferences = _Preferences(
      const NotificationPreferences(pushEnabled: true),
    );
    await _service(messaging, devices, preferences).disable('alice');
    expect(preferences.value.pushEnabled, false);
    expect(devices.unregistered, [messaging.currentToken]);
  });

  test(
    'already-allowed OS path registers without a runtime permission request',
    () async {
      final messaging = _Messaging(permission: PushPermissionState.allowed);
      final devices = _Devices();
      final preferences = _Preferences(
        const NotificationPreferences(pushEnabled: true),
      );
      final service = _service(messaging, devices, preferences);
      await service.startForUser('alice');
      messaging.refresh.add(
        'fcm-token-refreshed-yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy',
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(messaging.requests, 0);
      expect(devices.registered, [
        messaging.currentToken,
        'fcm-token-refreshed-yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy',
      ]);
      await service.dispose();
    },
  );

  test(
    'account change removes stale token when the new account has push off',
    () async {
      final messaging = _Messaging(permission: PushPermissionState.allowed);
      final devices = _Devices();
      final preferences = _Preferences(
        const NotificationPreferences(pushEnabled: true),
      );
      final service = _service(messaging, devices, preferences);
      await service.startForUser('alice');
      preferences.value = const NotificationPreferences(pushEnabled: false);
      await service.startForUser('bob');
      expect(devices.registered, [messaging.currentToken]);
      expect(devices.unregistered, [messaging.currentToken]);
      await service.dispose();
    },
  );

  test(
    'account change ignores an in-flight refresh from the old account',
    () async {
      final messaging = _Messaging(permission: PushPermissionState.allowed);
      final devices = _Devices();
      final preferences = _Preferences(
        const NotificationPreferences(pushEnabled: true),
      );
      final service = _service(messaging, devices, preferences);
      await service.startForUser('alice');

      final staleLoad = Completer<NotificationPreferences>();
      preferences.nextLoad = staleLoad;
      messaging.refresh.add('fcm-token-stale-zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz');
      await Future<void>.delayed(Duration.zero);

      preferences.value = const NotificationPreferences(pushEnabled: false);
      await service.startForUser('bob');
      staleLoad.complete(const NotificationPreferences(pushEnabled: true));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(devices.registered, [messaging.currentToken]);
      expect(devices.unregistered, [messaging.currentToken]);
      await service.dispose();
    },
  );

  test('sign-out proceeds after unregister failure', () async {
    final messaging = _Messaging(permission: PushPermissionState.allowed);
    final devices = _Devices()..failUnregister = true;
    final service = _service(messaging, devices, _Preferences());
    var signedOut = false;
    await signOutWithPushCleanup(
      pushService: service,
      signOut: () async => signedOut = true,
    );
    expect(devices.unregistered, [messaging.currentToken]);
    expect(signedOut, true);
  });

  testWidgets('permission states and explicit enable are rendered', (
    tester,
  ) async {
    final messaging = _Messaging(permission: PushPermissionState.denied);
    final preferences = _Preferences();
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(
          uid: 'alice',
          repository: preferences,
          pushService: _service(messaging, _Devices(), preferences),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Notifications blocked in device settings'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('push-notifications-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Enable push notifications?'), findsOneWidget);
    expect(messaging.requests, 0);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(messaging.requests, 1);
    expect(
      find.text('Notifications blocked in device settings'),
      findsOneWidget,
    );
    expect(find.textContaining('Open your device Settings'), findsOneWidget);
  });

  testWidgets('categories stay editable while push is off', (tester) async {
    final preferences = _Preferences();
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(
          uid: 'alice',
          repository: preferences,
          pushService: _service(_Messaging(), _Devices(), preferences),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match messages'));
    await tester.pumpAndSettle();
    expect(preferences.value.matchMessages, false);
    expect(preferences.value.pushEnabled, false);
  });

  testWidgets(
    'unsupported build disables push without requesting or tokenizing',
    (tester) async {
      final messaging = _UnsupportedMessaging();
      final preferences = _Preferences();
      final service = _service(messaging, _Devices(), preferences);
      await service.startForUser('alice');
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            uid: 'alice',
            repository: preferences,
            pushService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unavailable in this build'), findsOneWidget);
      expect(find.byKey(const Key('push-build-unavailable')), findsOneWidget);
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('push-notifications-toggle')),
      );
      expect(toggle.onChanged, isNull);
      expect(messaging.requests, 0);
      expect(messaging.tokenReads, 0);
    },
  );
}
