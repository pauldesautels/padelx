import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:padelx/main.dart';

void main() {
  testWidgets('create match form requires all fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateMatchScreen()));

    expect(find.text('Set up a new game'), findsOneWidget);
    expect(find.text('Create Match'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilledButton, 'Create Match'));
    await tester.pump();

    expect(find.text('Please fill in all fields'), findsOneWidget);
  });
}
