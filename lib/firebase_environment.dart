import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

const productionFirebaseProjectId = 'padelx-f168f';
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
}) {
  final selectedEnvironment = environment.trim();
  final selectedProjectId = projectId.trim();

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
