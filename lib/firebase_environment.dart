import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

FirebaseOptions firebaseOptionsForCurrentEnvironment() {
  const environment = String.fromEnvironment(
    'FIREBASE_ENVIRONMENT',
    defaultValue: 'development',
  );
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  if (projectId.isEmpty) {
    if (environment != 'development') {
      throw StateError(
        'FIREBASE_PROJECT_ID is required outside the development environment.',
      );
    }
    return DefaultFirebaseOptions.currentPlatform;
  }

  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  if (apiKey.isEmpty || appId.isEmpty || messagingSenderId.isEmpty) {
    throw StateError(
      'FIREBASE_API_KEY, FIREBASE_APP_ID, and '
      'FIREBASE_MESSAGING_SENDER_ID are required with FIREBASE_PROJECT_ID.',
    );
  }

  final defaults = DefaultFirebaseOptions.currentPlatform;
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
    iosBundleId: defaults.iosBundleId,
  );
}
