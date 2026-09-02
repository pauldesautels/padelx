import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/firebase_environment.dart';

const _apiKey = 'test-api-key';
const _appId = 'test-app-id';
const _senderId = 'test-sender-id';

void main() {
  group('Firebase environment safety', () {
    test('current environment fails closed when no defines are supplied', () {
      expect(firebaseOptionsForCurrentEnvironment, throwsA(isA<StateError>()));
    });

    test('missing development config fails closed', () {
      expect(
        () => firebaseOptionsForEnvironment(
          environment: '',
          projectId: '',
          apiKey: '',
          appId: '',
          messagingSenderId: '',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => firebaseOptionsForEnvironment(
          environment: 'development',
          projectId: '',
          apiKey: '',
          appId: '',
          messagingSenderId: '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('development cannot target padelx-f168f', () {
      expect(
        () => _options('development', productionFirebaseProjectId),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('cannot target the production project'),
          ),
        ),
      );
    });

    test('debug builds cannot target padelx-f168f', () {
      expect(
        () => firebaseOptionsForEnvironment(
          environment: 'production',
          projectId: productionFirebaseProjectId,
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          isDebugBuild: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Debug builds cannot target'),
          ),
        ),
      );
    });

    test('staging requires explicit Firebase values', () {
      expect(
        () => firebaseOptionsForEnvironment(
          environment: 'staging',
          projectId: 'padelx-staging',
          apiKey: '',
          appId: _appId,
          messagingSenderId: _senderId,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('FIREBASE_API_KEY'),
          ),
        ),
      );
    });

    test('staging accepts padelx-staging', () {
      final options = _options('staging', 'padelx-staging');
      expect(options.projectId, 'padelx-staging');
      expect(options.apiKey, _apiKey);
    });

    test('production requires explicit values', () {
      expect(
        () => firebaseOptionsForEnvironment(
          environment: 'production',
          projectId: productionFirebaseProjectId,
          apiKey: _apiKey,
          appId: '',
          messagingSenderId: _senderId,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('FIREBASE_APP_ID'),
          ),
        ),
      );
    });

    test('production accepts only explicit production selection', () {
      final options = _options('production', productionFirebaseProjectId);
      expect(options.projectId, productionFirebaseProjectId);

      expect(
        () => _options('staging', productionFirebaseProjectId),
        throwsA(isA<StateError>()),
      );
      expect(
        () => _options('production', 'padelx-staging'),
        throwsA(isA<StateError>()),
      );
    });

    test('example placeholders are rejected without exposing values', () {
      expect(
        () => firebaseOptionsForEnvironment(
          environment: 'staging',
          projectId: 'padelx-staging',
          apiKey: 'replace-with-staging-app-api-key',
          appId: _appId,
          messagingSenderId: _senderId,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('placeholder'),
              isNot(contains('replace-with-staging-app-api-key')),
            ),
          ),
        ),
      );
    });
  });
}

FirebaseOptions _options(String environment, String projectId) {
  return firebaseOptionsForEnvironment(
    environment: environment,
    projectId: projectId,
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _senderId,
  );
}
