import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/design_system.dart';

void main() {
  test('dark visual tokens keep brand accent separate from primary action', () {
    final theme = buildPadelXTheme();
    expect(theme.scaffoldBackgroundColor, PadelXColors.background);
    expect(theme.colorScheme.primary, PadelXColors.accent);
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
      PadelXColors.primaryAction,
    );
    expect(PadelXColors.teamOne, isNot(PadelXColors.teamTwo));
    expect(PadelXColors.primaryAction, isNot(PadelXColors.accent));
  });

  testWidgets('shared surface remains responsive at 320pt and 1.6 text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPadelXTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: PadelXSurface(
                accent: PadelXColors.teamOne,
                child: Column(
                  children: [
                    Text('Team 1 — confirmed players'),
                    PadelXMetric(
                      icon: Icons.verified_outlined,
                      label: 'Reliability 95%',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Reliability 95%'), findsOneWidget);
  });
}
