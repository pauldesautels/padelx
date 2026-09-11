import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/firebase_diagnostics.dart';

void main() {
  test('Firebase diagnostics expose only plugin code and safe category', () {
    final result = safeFirebaseFailure(
      FirebaseException(
        plugin: 'firebase_firestore',
        code: 'permission-denied',
        message: 'secret-token private@example.com conversation-123',
      ),
    );

    expect(
      result,
      '[firebase_firestore/permission-denied; authorization-or-app-check]',
    );
    expect(result, isNot(contains('secret-token')));
    expect(result, isNot(contains('private@example.com')));
    expect(result, isNot(contains('conversation-123')));
  });

  test('unsafe labels and non-Firebase failures remain non-sensitive', () {
    expect(
      safeFirebaseFailure(
        FirebaseException(
          plugin: 'firebase/firestore/private',
          code: 'bad code containing details',
          message: 'do not print me',
        ),
      ),
      '[firebase/unknown; unknown]',
    );
    expect(
      safeFirebaseFailure(StateError('private value')),
      '[non-firebase/unknown; unknown]',
    );
  });
}
