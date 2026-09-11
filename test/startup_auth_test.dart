import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/auth_landing.dart';
import 'package:padelx/branding.dart';
import 'package:padelx/startup.dart';

void main() {
  testWidgets('ready startup preserves the 2.3 second branded sequence', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartupCoordinator(
          initialize: (report) async => report(0.95),
          destinationBuilder: (_) => const Text('READY DESTINATION'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('startup-screen')), findsOneWidget);
    expect(find.text('READY DESTINATION'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2299));
    expect(find.text('READY DESTINATION'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('startup-progress')),
          )
          .value,
      lessThan(1),
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('READY DESTINATION'), findsOneWidget);
  });

  testWidgets('minimum duration never overrides slower real readiness', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: StartupCoordinator(
          initialize: (report) {
            report(0.5);
            return ready.future;
          },
          destinationBuilder: (_) => const Text('READY DESTINATION'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('startup-screen')), findsOneWidget);
    expect(find.text('READY DESTINATION'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('startup-progress')),
          )
          .value,
      inInclusiveRange(0.05, 0.5),
    );

    ready.complete();
    await tester.pump();
    expect(find.text('READY DESTINATION'), findsOneWidget);
  });

  testWidgets('startup progress waits for real readiness before destination', (
    tester,
  ) async {
    final ready = Completer<void>();
    late ValueChanged<double> report;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupCoordinator(
          initialize: (callback) {
            report = callback;
            callback(0.5);
            return ready.future;
          },
          destinationBuilder: (_) => const Text('READY DESTINATION'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('startup-screen')), findsOneWidget);
    expect(find.text('READY DESTINATION'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('startup-progress')),
          )
          .value,
      inInclusiveRange(0.05, 0.5),
    );

    report(0.95);
    await tester.pump();
    expect(find.text('READY DESTINATION'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('READY DESTINATION'), findsOneWidget);
  });

  testWidgets('startup failure is safe and retryable', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupCoordinator(
          initialize: (_) async {
            attempts++;
            if (attempts == 1) throw StateError('internal configuration');
          },
          destinationBuilder: (_) => const Text('READY DESTINATION'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PadelX could not start.'), findsOneWidget);
    expect(find.textContaining('internal configuration'), findsNothing);
    await tester.tap(find.byKey(const Key('startup-retry')));
    await tester.pumpAndSettle();
    expect(find.text('READY DESTINATION'), findsOneWidget);
  });

  testWidgets('reduced motion removes the orbit without blocking readiness', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StartupCoordinator(
            initialize: (_) => ready.future,
            destinationBuilder: (_) => const Text('READY DESTINATION'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('startup-orbit')), findsNothing);
    expect(find.byType(PadelXBrandMark), findsOneWidget);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('READY DESTINATION'), findsOneWidget);
  });

  testWidgets('auth landing uses canonical brand and only supported email', (
    tester,
  ) async {
    var emailOpened = false;
    await tester.pumpWidget(
      MaterialApp(home: AuthLandingScreen(onEmail: () => emailOpened = true)),
    );
    expect(find.byType(PadelXBrandMark), findsOneWidget);
    expect(find.text('PADELX'), findsOneWidget);
    expect(find.text('Find your next match.'), findsOneWidget);
    expect(find.text('Play more padel with players near you.'), findsOneWidget);
    expect(find.textContaining('Apple'), findsNothing);
    expect(find.textContaining('Google'), findsNothing);
    expect(find.textContaining('Facebook'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue-with-email')));
    expect(emailOpened, true);
  });

  testWidgets('auth landing remains usable on a small large-text screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: AuthLandingScreen(onEmail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('continue-with-email')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
