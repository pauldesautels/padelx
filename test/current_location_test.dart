import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/current_location.dart';

void main() {
  test('location errors provide actionable user messages', () {
    for (final error in CurrentLocationError.values) {
      final message = CurrentLocationException(error).userMessage;
      expect(message, isNotEmpty);
      expect(
        message,
        anyOf(
          contains('search manually'),
          contains('search for a location manually'),
          contains('try again'),
        ),
      );
    }
  });

  test('permanently denied permission directs users to settings', () {
    const exception = CurrentLocationException(
      CurrentLocationError.permissionPermanentlyDenied,
    );
    expect(exception.userMessage, contains('settings'));
  });
}
