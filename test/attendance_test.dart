import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/attendance.dart';
import 'package:padelx/l10n/app_localizations.dart';

Widget app(Widget child, {Locale locale = const Locale('en'), double scale = 1}) => MaterialApp(
  locale: locale, localizationsDelegates: const [AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale)), child: Scaffold(body: child)));

void main() {
  testWidgets('attendance action is accessible and submitted state is disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(AttendanceAction(submitted: false, busy: false, onPressed: () => taps++)));
    await tester.tap(find.byKey(const Key('confirm-attendance-action')));
    expect(taps, 1);
    await tester.pumpWidget(app(AttendanceAction(submitted: true, busy: false, onPressed: () => taps++)));
    expect(find.text('Attendance submitted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-attendance-action')));
    expect(taps, 1);
  });

  testWidgets('dialog captures who played and match-not-played without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AttendanceSelection? result;
    await tester.pumpWidget(app(Builder(builder: (context) => ElevatedButton(onPressed: () async {
      result = await showDialog<AttendanceSelection>(context: context,
        builder: (_) => const AttendanceConfirmationDialog(participants: [
          AttendanceParticipant('a', 'Paul'), AttendanceParticipant('b', 'Carlos'),
          AttendanceParticipant('c', 'Ana'), AttendanceParticipant('d', 'Miguel'),
        ]));
    }, child: const Text('Open'))), scale: 1.6));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Who played?'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('attendance-player-d')));
    await tester.tap(find.byKey(const Key('attendance-player-d')));
    await tester.ensureVisible(find.byKey(const Key('attendance-submit')));
    await tester.tap(find.byKey(const Key('attendance-submit')));
    await tester.pumpAndSettle();
    expect(result?.matchHappened, true);
    expect(result?.attendedUids, isNot(contains('d')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('es-MX attendance flow uses localized neutral copy', (tester) async {
    await tester.pumpWidget(app(const AttendanceConfirmationDialog(participants: [
      AttendanceParticipant('a', 'Ana'), AttendanceParticipant('b', 'Beto'),
    ]), locale: const Locale('es', 'MX')));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar asistencia'), findsOneWidget);
    expect(find.text('¿Quién jugó?'), findsOneWidget);
    expect(find.textContaining('no se jugó'), findsOneWidget);
  });
}
