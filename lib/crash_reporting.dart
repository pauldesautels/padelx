import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract interface class CrashReporter {
  Future<void> initialize();
  Future<void> recordNonFatal(Object error, StackTrace stack, String operation);
}

bool crashCollectionEnabled({required bool isDebug, required bool isWeb}) =>
    !isDebug && !isWeb;

Map<String, String> crashMetadata({
  required String environment,
  required String buildNumber,
}) => {'environment': environment, 'build_number': buildNumber};

class FirebaseCrashReporter implements CrashReporter {
  FirebaseCrashReporter({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> initialize() async {
    if (kIsWeb) return;
    // Debug sessions remain local. TestFlight/release builds report to the
    // Firebase project selected by the existing fail-closed environment seam.
    final enabled = crashCollectionEnabled(isDebug: kDebugMode, isWeb: false);
    await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
    if (!enabled) return;
    final package = await PackageInfo.fromPlatform();
    final metadata = crashMetadata(
      environment: const String.fromEnvironment('FIREBASE_ENVIRONMENT'),
      buildNumber: package.buildNumber,
    );
    for (final entry in metadata.entries) {
      await _crashlytics.setCustomKey(entry.key, entry.value);
    }
    FlutterError.onError = _crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  @override
  Future<void> recordNonFatal(
    Object error,
    StackTrace stack,
    String operation,
  ) async {
    if (kDebugMode || kIsWeb) return;
    await _crashlytics.recordError(
      error,
      stack,
      reason: operation,
      fatal: false,
    );
  }
}

class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> recordNonFatal(
    Object error,
    StackTrace stack,
    String operation,
  ) async {}
}

CrashReporter crashReporter = const NoopCrashReporter();
