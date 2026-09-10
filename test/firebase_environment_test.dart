import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
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

    test('iOS staging accepts only complete native staging values', () {
      final options = _iosOptions();
      expect(options.projectId, stagingFirebaseProjectId);
      expect(options.appId, contains(':ios:'));
      expect(options.iosBundleId, stagingIosBundleId);
    });

    test('iOS staging rejects a web App ID', () {
      expect(
        () => _iosOptions(appId: '1:708585002488:web:abc'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('web and production App IDs are not accepted'),
          ),
        ),
      );
    });

    test('iOS staging rejects a production native App ID', () {
      expect(
        () => _iosOptions(appId: '1:425226080221:ios:abc'),
        throwsA(isA<StateError>()),
      );
    });

    test('iOS staging rejects production project and wrong bundle ID', () {
      expect(
        () => _iosOptions(projectId: productionFirebaseProjectId),
        throwsA(isA<StateError>()),
      );
      expect(
        () => _iosOptions(bundleId: 'com.example.padelx'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(stagingIosBundleId),
          ),
        ),
      );
    });

    test('iOS device test requires its bundle ID and a debug build', () {
      final options = _iosOptions(
        bundleId: deviceTestIosBundleId,
        isDebugBuild: true,
        isDeviceTestBuild: true,
      );
      expect(options.iosBundleId, deviceTestIosBundleId);
      expect(
        () => _iosOptions(
          bundleId: deviceTestIosBundleId,
          isDeviceTestBuild: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Android staging accepts only a native staging Android app', () {
      final options = firebaseOptionsForEnvironment(
        environment: 'staging',
        projectId: stagingFirebaseProjectId,
        apiKey: _apiKey,
        appId: '1:708585002488:android:abc',
        messagingSenderId: stagingMessagingSenderId,
        storageBucket: stagingStorageBucket,
        targetPlatform: TargetPlatform.android,
      );
      expect(options.projectId, stagingFirebaseProjectId);
      expect(
        () => firebaseOptionsForEnvironment(
          environment: 'staging',
          projectId: stagingFirebaseProjectId,
          apiKey: _apiKey,
          appId: '1:425226080221:android:production',
          messagingSenderId: stagingMessagingSenderId,
          storageBucket: stagingStorageBucket,
          targetPlatform: TargetPlatform.android,
        ),
        throwsA(isA<StateError>()),
      );
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

FirebaseOptions _iosOptions({
  String projectId = stagingFirebaseProjectId,
  String appId = '1:708585002488:ios:abc',
  String bundleId = stagingIosBundleId,
  bool isDebugBuild = false,
  bool isDeviceTestBuild = false,
}) {
  return firebaseOptionsForEnvironment(
    environment: 'staging',
    projectId: projectId,
    apiKey: _apiKey,
    appId: appId,
    messagingSenderId: stagingMessagingSenderId,
    storageBucket: stagingStorageBucket,
    iosBundleId: bundleId,
    isDebugBuild: isDebugBuild,
    isDeviceTestBuild: isDeviceTestBuild,
    targetPlatform: TargetPlatform.iOS,
  );
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
