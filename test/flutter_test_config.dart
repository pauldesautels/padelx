import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.localeTestValue = const Locale('en');
  try {
    await testMain();
  } finally {
    binding.platformDispatcher.clearLocaleTestValue();
  }
}
