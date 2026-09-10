import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum PushPermissionState { notDetermined, allowed, denied, unsupported }

class NotificationPreferences {
  final bool pushEnabled;
  final bool matchMessages;
  final bool joinRequests;
  final bool friendRequests;
  final bool friendAccepted;
  final bool matchUpdates;
  final bool playAgain;

  const NotificationPreferences({
    this.pushEnabled = false,
    this.matchMessages = true,
    this.joinRequests = true,
    this.friendRequests = true,
    this.friendAccepted = true,
    this.matchUpdates = true,
    this.playAgain = true,
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic>? data) {
    bool value(String key, bool fallback) =>
        data?[key] is bool ? data![key] as bool : fallback;
    return NotificationPreferences(
      pushEnabled: value('pushEnabled', false),
      matchMessages: value('matchMessages', true),
      joinRequests: value('joinRequests', true),
      friendRequests: value('friendRequests', true),
      friendAccepted: value('friendAccepted', true),
      matchUpdates: value('matchUpdates', true),
      playAgain: value('playAgain', true),
    );
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? matchMessages,
    bool? joinRequests,
    bool? friendRequests,
    bool? friendAccepted,
    bool? matchUpdates,
    bool? playAgain,
  }) => NotificationPreferences(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    matchMessages: matchMessages ?? this.matchMessages,
    joinRequests: joinRequests ?? this.joinRequests,
    friendRequests: friendRequests ?? this.friendRequests,
    friendAccepted: friendAccepted ?? this.friendAccepted,
    matchUpdates: matchUpdates ?? this.matchUpdates,
    playAgain: playAgain ?? this.playAgain,
  );

  Map<String, dynamic> toFirestore() => {
    'pushEnabled': pushEnabled,
    'matchMessages': matchMessages,
    'joinRequests': joinRequests,
    'friendRequests': friendRequests,
    'friendAccepted': friendAccepted,
    'matchUpdates': matchUpdates,
    'playAgain': playAgain,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

abstract class NotificationPreferencesRepository {
  Stream<NotificationPreferences> watch(String uid);
  Future<NotificationPreferences> load(String uid);
  Future<void> save(String uid, NotificationPreferences preferences);
}

class FirebaseNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  final FirebaseFirestore firestore;
  FirebaseNotificationPreferencesRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _reference(String uid) => firestore
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('notifications');

  @override
  Stream<NotificationPreferences> watch(String uid) => _reference(uid)
      .snapshots()
      .map((snapshot) => NotificationPreferences.fromMap(snapshot.data()));

  @override
  Future<NotificationPreferences> load(String uid) async =>
      NotificationPreferences.fromMap((await _reference(uid).get()).data());

  @override
  Future<void> save(String uid, NotificationPreferences preferences) =>
      _reference(uid).set(preferences.toFirestore());
}

abstract class PushMessagingGateway {
  Future<PushPermissionState> permissionState();
  Future<PushPermissionState> requestPermission();
  Future<String?> token();
  Stream<String> get tokenRefreshes;
}

class FirebasePushMessagingGateway implements PushMessagingGateway {
  final FirebaseMessaging messaging;
  FirebasePushMessagingGateway({FirebaseMessaging? messaging})
    : messaging = messaging ?? FirebaseMessaging.instance;

  PushPermissionState _map(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermissionState.allowed,
    AuthorizationStatus.denied => PushPermissionState.denied,
    AuthorizationStatus.deniedPermanently => PushPermissionState.denied,
    AuthorizationStatus.notDetermined => PushPermissionState.notDetermined,
  };

  @override
  Future<PushPermissionState> permissionState() async {
    if (kIsWeb ||
        !{
          TargetPlatform.iOS,
          TargetPlatform.android,
        }.contains(defaultTargetPlatform)) {
      return PushPermissionState.unsupported;
    }
    return _map(
      (await messaging.getNotificationSettings()).authorizationStatus,
    );
  }

  @override
  Future<PushPermissionState> requestPermission() async {
    if (kIsWeb ||
        !{
          TargetPlatform.iOS,
          TargetPlatform.android,
        }.contains(defaultTargetPlatform)) {
      return PushPermissionState.unsupported;
    }
    return _map(
      (await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      )).authorizationStatus,
    );
  }

  @override
  Future<String?> token() => messaging.getToken();

  @override
  Stream<String> get tokenRefreshes => messaging.onTokenRefresh;
}

abstract class PushDeviceRepository {
  Future<void> register(String token);
  Future<void> unregister(String token);
}

class FirebasePushDeviceRepository implements PushDeviceRepository {
  final FirebaseFunctions functions;
  final FirebaseApp app;
  final TargetPlatform platform;
  final Future<String> Function() loadAndroidPackageName;
  FirebasePushDeviceRepository({
    FirebaseFunctions? functions,
    FirebaseApp? app,
    TargetPlatform? platform,
    Future<String> Function()? loadAndroidPackageName,
  }) : functions = functions ?? FirebaseFunctions.instance,
       app = app ?? Firebase.app(),
       platform = platform ?? defaultTargetPlatform,
       loadAndroidPackageName =
           loadAndroidPackageName ??
           (() async => (await PackageInfo.fromPlatform()).packageName);

  Future<Map<String, Object>> _payload(String token) async {
    final identity = switch (platform) {
      TargetPlatform.iOS => <String, Object>{
        'platform': 'ios',
        'bundleId': app.options.iosBundleId ?? '',
      },
      TargetPlatform.android => <String, Object>{
        'platform': 'android',
        'packageName': await loadAndroidPackageName(),
      },
      _ => throw UnsupportedError('Push registration is unavailable.'),
    };
    return {
      'token': token,
      'firebaseProjectId': app.options.projectId,
      'firebaseAppId': app.options.appId,
      ...identity,
    };
  }

  @override
  Future<void> register(String token) async {
    await functions
        .httpsCallable('registerPushDevice')
        .call(await _payload(token));
  }

  @override
  Future<void> unregister(String token) async {
    await functions
        .httpsCallable('unregisterPushDevice')
        .call(await _payload(token));
  }
}

abstract class PushSettingsService {
  Future<PushPermissionState> permissionState();
  Future<PushPermissionState> enable(String uid);
  Future<void> disable(String uid);
}

Future<void> signOutWithPushCleanup({
  required PushNotificationService? pushService,
  required Future<void> Function() signOut,
}) async {
  await pushService?.unregisterBeforeSignOut();
  await signOut();
}

class PushNotificationService implements PushSettingsService {
  final PushMessagingGateway messaging;
  final PushDeviceRepository devices;
  final NotificationPreferencesRepository preferences;
  StreamSubscription<String>? _tokenSubscription;
  String? _activeUid;
  String? _currentToken;
  int _sessionGeneration = 0;

  PushNotificationService({
    required this.messaging,
    required this.devices,
    required this.preferences,
  });

  static PushNotificationService firebase() => PushNotificationService(
    messaging: FirebasePushMessagingGateway(),
    devices: FirebasePushDeviceRepository(),
    preferences: FirebaseNotificationPreferencesRepository(),
  );

  Future<void> startForUser(String? uid) async {
    final generation = ++_sessionGeneration;
    _activeUid = uid;
    await _tokenSubscription?.cancel();
    _tokenSubscription = messaging.tokenRefreshes.listen((token) async {
      final refreshGeneration = _sessionGeneration;
      final activeUid = _activeUid;
      if (activeUid == null) return;
      try {
        final stored = await preferences.load(activeUid);
        final permission = await messaging.permissionState();
        if (refreshGeneration != _sessionGeneration ||
            _activeUid != activeUid) {
          return;
        }
        _currentToken = token;
        if (stored.pushEnabled && permission == PushPermissionState.allowed) {
          await devices.register(token);
        } else {
          await devices.unregister(token);
        }
      } catch (error) {
        debugPrint(
          'Push token refresh synchronization failed: ${error.runtimeType}.',
        );
      }
    });
    if (uid == null) return;
    try {
      final stored = await preferences.load(uid);
      final permission = await messaging.permissionState();
      final token = permission == PushPermissionState.allowed
          ? await messaging.token()
          : null;
      _currentToken = token;
      if (token == null ||
          generation != _sessionGeneration ||
          _activeUid != uid) {
        return;
      }
      if (stored.pushEnabled) {
        await devices.register(token);
      } else {
        await devices.unregister(token);
      }
    } catch (error) {
      debugPrint(
        'Push registration synchronization failed: ${error.runtimeType}.',
      );
    }
  }

  @override
  Future<PushPermissionState> permissionState() => messaging.permissionState();

  @override
  Future<PushPermissionState> enable(String uid) async {
    final permission = await messaging.requestPermission();
    if (permission != PushPermissionState.allowed) return permission;
    final token = await messaging.token();
    if (token == null || token.isEmpty) {
      throw StateError('Push token is unavailable.');
    }
    await devices.register(token);
    _activeUid = uid;
    _currentToken = token;
    final stored = await preferences.load(uid);
    try {
      await preferences.save(uid, stored.copyWith(pushEnabled: true));
    } catch (_) {
      try {
        await devices.unregister(token);
      } catch (_) {
        // The authoritative preference remains disabled, so delivery stays off.
      }
      rethrow;
    }
    return permission;
  }

  @override
  Future<void> disable(String uid) async {
    final stored = await preferences.load(uid);
    await preferences.save(uid, stored.copyWith(pushEnabled: false));
    final token = _currentToken ?? await messaging.token();
    if (token == null || token.isEmpty) return;
    try {
      await devices.unregister(token);
    } catch (error) {
      debugPrint('Push device unregister failed: ${error.runtimeType}.');
    }
  }

  Future<void> unregisterBeforeSignOut() async {
    try {
      final token = _currentToken ?? await messaging.token();
      if (token == null || token.isEmpty) return;
      await devices.unregister(token);
    } catch (error) {
      debugPrint('Push sign-out unregister failed: ${error.runtimeType}.');
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
  }
}
