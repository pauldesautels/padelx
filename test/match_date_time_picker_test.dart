import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/match_date_time_picker.dart';

void main() {
  final now = DateTime(2026, 9, 10, 10, 15);
  final initial = DateTime(2026, 9, 12, 18, 30);

  Future<DateTime?> openIosPicker(WidgetTester tester) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showAdaptiveMatchDateTimePicker(
                context,
                now: now,
                initialValue: initial,
                platform: TargetPlatform.iOS,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets(
    'iOS uses a bounded date-and-time wheel with accessible actions',
    (tester) async {
      await openIosPicker(tester);
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.mode, CupertinoDatePickerMode.dateAndTime);
      expect(picker.initialDateTime, initial);
      expect(picker.minimumDate, now.add(const Duration(minutes: 1)));
      expect(picker.maximumDate, DateTime(now.year + 5));
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    },
  );

  testWidgets('iOS Cancel preserves the prior value', (tester) async {
    DateTime? result = initial;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showAdaptiveMatchDateTimePicker(
                context,
                now: now,
                initialValue: initial,
                platform: TargetPlatform.iOS,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('iOS Done returns the selected value', (tester) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showAdaptiveMatchDateTimePicker(
                context,
                now: now,
                initialValue: initial,
                platform: TargetPlatform.iOS,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, initial);
  });
}
