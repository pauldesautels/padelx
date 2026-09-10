import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;

const productionFirebaseProjectId = 'padelx-f168f';
const stagingFirebaseProjectId = 'padelx-staging';
const stagingIosBundleId = 'com.padelx.app.staging';
const deviceTestIosBundleId = 'com.padelx.app.devicetest';
const stagingAndroidPackageName = 'com.example.padelx';
const stagingMessagingSenderId = '708585002488';
const stagingStorageBucket = 'padelx-staging.firebasestorage.app';
const _supportedFirebaseEnvironments = {'development', 'staging', 'production'};

FirebaseOptions firebaseOptionsForCurrentEnvironment() {
  return firebaseOptionsForEnvironment(
    environment: const String.fromEnvironment('FIREBASE_ENVIRONMENT'),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
    appId: const String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
    isDebugBuild: kDebugMode,
    isDeviceTestBuild: const bool.fromEnvironment('PADELX_IOS_DEVICE_TEST'),
    isWeb: kIsWeb,
    targetPlatform: defaultTargetPlatform,
  );
}

FirebaseOptions firebaseOptionsForEnvironment({
  required String environment,
  required String projectId,
  required String apiKey,
  required String appId,
  required String messagingSenderId,
  String authDomain = '',
  String storageBucket = '',
  String iosBundleId = '',
  bool isDebugBuild = false,
  bool isDeviceTestBuild = false,
  bool isWeb = false,
  TargetPlatform? targetPlatform,
}) {
  final selectedEnvironment = environment.trim();
  final selectedProjectId = projectId.trim();

  if (isDeviceTestBuild && selectedEnvironment != 'staging') {
    throw StateError(
      'PADELX_IOS_DEVICE_TEST requires FIREBASE_ENVIRONMENT=staging.',
    );
  }

  if (!_supportedFirebaseEnvironments.contains(selectedEnvironment)) {
    throw StateError(
      'FIREBASE_ENVIRONMENT must be explicitly set to development, staging, '
      'or production.',
    );
  }

  if (selectedEnvironment != 'production' &&
      selectedProjectId == productionFirebaseProjectId) {
    throw StateError(
      'Non-production Firebase environments cannot target the production '
      'project.',
    );
  }

  if (isDebugBuild && selectedProjectId == productionFirebaseProjectId) {
    throw StateError('Debug builds cannot target the production project.');
  }

  if (selectedEnvironment == 'production' &&
      selectedProjectId != productionFirebaseProjectId) {
    throw StateError(
      'The production Firebase environment must explicitly target the '
      'production project.',
    );
  }

  final requiredValues = <String, String>{
    'FIREBASE_PROJECT_ID': selectedProjectId,
    'FIREBASE_API_KEY': apiKey.trim(),
    'FIREBASE_APP_ID': appId.trim(),
    'FIREBASE_MESSAGING_SENDER_ID': messagingSenderId.trim(),
  };
  final missingNames = requiredValues.entries
      .where((entry) => entry.value.isEmpty)
      .map((entry) => entry.key)
      .toList(growable: false);
  if (missingNames.isNotEmpty) {
    throw StateError(
      'Explicit Firebase configuration is required. Missing: '
      '${missingNames.join(', ')}.',
    );
  }

  if (requiredValues.values.any((value) => value.startsWith('replace-with-'))) {
    throw StateError(
      'Firebase configuration still contains example placeholder values.',
    );
  }

  final isIos = !isWeb && targetPlatform == TargetPlatform.iOS;
  final isAndroid = !isWeb && targetPlatform == TargetPlatform.android;
  if (selectedEnvironment == 'staging' && isIos) {
    final selectedAppId = requiredValues['FIREBASE_APP_ID']!;
    final selectedBundleId = iosBundleId.trim();
    final selectedSenderId = requiredValues['FIREBASE_MESSAGING_SENDER_ID']!;
    final selectedStorageBucket = storageBucket.trim();

    if (selectedProjectId != stagingFirebaseProjectId) {
      throw StateError(
        'iOS staging requires FIREBASE_PROJECT_ID=padelx-staging.',
      );
    }
    if (!selectedAppId.startsWith('1:$stagingMessagingSenderId:ios:')) {
      throw StateError(
        'iOS staging requires a native Firebase iOS App ID owned by '
        'padelx-staging; web and production App IDs are not accepted.',
      );
    }
    if (isDeviceTestBuild && !isDebugBuild) {
      throw StateError(
        'PADELX_IOS_DEVICE_TEST is allowed only in debug builds.',
      );
    }
    final expectedBundleId = isDeviceTestBuild
        ? deviceTestIosBundleId
        : stagingIosBundleId;
    if (selectedBundleId != expectedBundleId) {
      throw StateError(
        'iOS staging requires FIREBASE_IOS_BUNDLE_ID=$expectedBundleId.',
      );
    }
    if (selectedSenderId != stagingMessagingSenderId) {
      throw StateError('iOS staging has an unexpected messaging sender ID.');
    }
    if (selectedStorageBucket != stagingStorageBucket) {
      throw StateError('iOS staging has an unexpected storage bucket.');
    }
  }
  if (selectedEnvironment == 'staging' && isAndroid) {
    final selectedAppId = requiredValues['FIREBASE_APP_ID']!;
    final selectedSenderId = requiredValues['FIREBASE_MESSAGING_SENDER_ID']!;
    final selectedStorageBucket = storageBucket.trim();
    if (selectedProjectId != stagingFirebaseProjectId ||
        !selectedAppId.startsWith('1:$stagingMessagingSenderId:android:') ||
        selectedSenderId != stagingMessagingSenderId ||
        selectedStorageBucket != stagingStorageBucket) {
      throw StateError(
        'Android staging requires a native Android Firebase app owned by '
        'padelx-staging with the expected sender and storage identities.',
      );
    }
  }

  return FirebaseOptions(
    apiKey: requiredValues['FIREBASE_API_KEY']!,
    appId: requiredValues['FIREBASE_APP_ID']!,
    messagingSenderId: requiredValues['FIREBASE_MESSAGING_SENDER_ID']!,
    projectId: requiredValues['FIREBASE_PROJECT_ID']!,
    authDomain: _optionalValue(authDomain),
    storageBucket: _optionalValue(storageBucket),
    iosBundleId: _optionalValue(iosBundleId),
  );
}

String? _optionalValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
