import 'package:firebase_core/firebase_core.dart';

String safeFirebaseFailure(Object error) {
  if (error is! FirebaseException) {
    return '[non-firebase/unknown; unknown]';
  }
  final plugin = _safeLabel(error.plugin, fallback: 'firebase');
  final code = _safeLabel(error.code, fallback: 'unknown');
  return '[$plugin/$code; ${firebaseFailureCategory(code)}]';
}

String firebaseFailureCategory(String code) => switch (code) {
  'permission-denied' => 'authorization-or-app-check',
  'unauthenticated' => 'authentication-or-app-check',
  'unavailable' ||
  'deadline-exceeded' ||
  'network-request-failed' => 'connectivity',
  'failed-precondition' => 'precondition',
  'not-found' => 'not-found',
  _ => 'unknown',
};

String _safeLabel(String value, {required String fallback}) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty ||
      !RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(normalized)) {
    return fallback;
  }
  return normalized;
}
