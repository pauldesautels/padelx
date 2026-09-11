import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/eligibility.dart';
import 'package:padelx/main.dart';

class _FakeEligibilityRepository implements EligibilityRepository {
  _FakeEligibilityRepository({this.eligible = false, this.getError});

  bool eligible;
  Object? getError;
  Object? recordError;
  int getCalls = 0;
  int recordCalls = 0;
  final List<String> requestIds = [];

  @override
  Future<bool> getEligibility() async {
    getCalls++;
    if (getError != null) throw getError!;
    return eligible;
  }

  @override
  Future<void> recordEligibility({required String requestId}) async {
    recordCalls++;
    requestIds.add(requestId);
    if (recordError != null) throw recordError!;
    eligible = true;
  }
}

class _RegistrationRaceHarness extends StatefulWidget {
  final _FakeEligibilityRepository repository;

  const _RegistrationRaceHarness({super.key, required this.repository});

  @override
  State<_RegistrationRaceHarness> createState() =>
      _RegistrationRaceHarnessState();
}

class _RegistrationRaceHarnessState extends State<_RegistrationRaceHarness> {
  int generation = 0;
  bool showRegistration = true;
  int userCreations = 0;
  int verificationEmails = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Stack(
      children: [
        AgeEligibilityGate(
          key: ValueKey('new-user-$generation'),
          repository: widget.repository,
          eligibleBuilder: (_) => const Scaffold(body: Text('VERIFY EMAIL')),
        ),
        if (showRegistration)
          AuthScreen(
            signUpHandler: (_, _) async => userCreations++,
            ageEligibilityRecorder: (requestId) =>
                widget.repository.recordEligibility(requestId: requestId),
            onEligibilityRecorded: () => setState(() => generation++),
            emailVerificationSender: () async => verificationEmails++,
            onAuthenticationSucceeded: () =>
                setState(() => showRegistration = false),
          ),
      ],
    ),
  );
}

void main() {
  testWidgets('Sign Up requires age confirmation while Log In does not', (
    tester,
  ) async {
    var signUps = 0;
    var recordings = 0;
    var verifications = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          signUpHandler: (_, _) async => signUps++,
          ageEligibilityRecorder: (_) async => recordings++,
          emailVerificationSender: () async => verifications++,
        ),
      ),
    );
    expect(find.byKey(const Key('signup-age-checkbox')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('auth-switch-mode')));
    await tester.tap(find.byKey(const Key('auth-switch-mode')));
    await tester.pump();
    expect(find.byKey(const Key('signup-age-checkbox')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth-submit')))
          .onPressed,
      isNull,
    );
    expect(signUps, 0);
    expect(recordings, 0);
    expect(verifications, 0);
  });

  testWidgets(
    'unchecked Sign Up password action dismisses without submitting',
    (tester) async {
      var signUps = 0;
      var recordings = 0;
      var verifications = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(
            signUpHandler: (_, _) async => signUps++,
            ageEligibilityRecorder: (_) async => recordings++,
            emailVerificationSender: () async => verifications++,
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('auth-switch-mode')));
      await tester.tap(find.byKey(const Key('auth-switch-mode')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'new@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'secret12',
      );
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
      expect(signUps, 0);
      expect(recordings, 0);
      expect(verifications, 0);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.textContaining('Confirm that you are 18'), findsOneWidget);
    },
  );

  testWidgets('checked Sign Up password action submits exactly once', (
    tester,
  ) async {
    var signUps = 0;
    var recordings = 0;
    var verifications = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          signUpHandler: (_, _) async => signUps++,
          ageEligibilityRecorder: (_) async => recordings++,
          emailVerificationSender: () async => verifications++,
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('auth-switch-mode')));
    await tester.tap(find.byKey(const Key('auth-switch-mode')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'new@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret12');
    await tester.ensureVisible(find.byKey(const Key('signup-age-checkbox')));
    await tester.tap(find.byKey(const Key('signup-age-checkbox')));
    await tester.showKeyboard(find.byKey(const Key('auth-password')));

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(signUps, 1);
    expect(recordings, 1);
    expect(verifications, 1);
  });

  testWidgets('Login password action continues to submit normally', (
    tester,
  ) async {
    var logins = 0;
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(loginHandler: (_, _) async => logins++)),
    );
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'player@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret12');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(logins, 1);
  });

  testWidgets('Sign Up records eligibility before sending verification', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          signUpHandler: (_, _) async => events.add('auth'),
          ageEligibilityRecorder: (_) async => events.add('eligibility'),
          emailVerificationSender: () async => events.add('verification'),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('auth-switch-mode')));
    await tester.tap(find.byKey(const Key('auth-switch-mode')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'new@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret12');
    await tester.ensureVisible(find.byKey(const Key('signup-age-checkbox')));
    await tester.tap(find.byKey(const Key('signup-age-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(events, ['auth', 'eligibility', 'verification']);
  });

  testWidgets(
    'registration completion rechecks a gate that raced ahead of recording',
    (tester) async {
      final repository = _FakeEligibilityRepository();
      final harnessKey = GlobalKey<_RegistrationRaceHarnessState>();
      await tester.pumpWidget(
        _RegistrationRaceHarness(key: harnessKey, repository: repository),
      );
      await tester.pumpAndSettle();

      // The authenticated gate has already resolved the still-missing record.
      expect(repository.getCalls, 1);
      await tester.ensureVisible(find.byKey(const Key('auth-switch-mode')));
      await tester.tap(find.byKey(const Key('auth-switch-mode')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'new@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'secret12',
      );
      await tester.ensureVisible(find.byKey(const Key('signup-age-checkbox')));
      await tester.tap(find.byKey(const Key('signup-age-checkbox')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(harnessKey.currentState!.userCreations, 1);
      expect(harnessKey.currentState!.verificationEmails, 1);
      expect(repository.recordCalls, 1);
      expect(repository.getCalls, 2);
      expect(find.text('VERIFY EMAIL'), findsOneWidget);
      expect(find.byKey(const Key('age-eligibility-checkbox')), findsNothing);
    },
  );

  testWidgets('failed post-Auth eligibility retries without another account', (
    tester,
  ) async {
    var signUps = 0;
    var recordings = 0;
    var verifications = 0;
    final requestIds = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          signUpHandler: (_, _) async => signUps++,
          ageEligibilityRecorder: (requestId) async {
            recordings++;
            requestIds.add(requestId);
            if (recordings == 1) throw StateError('private detail');
          },
          emailVerificationSender: () async => verifications++,
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('auth-switch-mode')));
    await tester.tap(find.byKey(const Key('auth-switch-mode')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'new@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret12');
    await tester.ensureVisible(find.byKey(const Key('signup-age-checkbox')));
    await tester.tap(find.byKey(const Key('signup-age-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(signUps, 1);
    expect(verifications, 0);
    expect(find.textContaining('account was created'), findsOneWidget);
    expect(find.textContaining('private detail'), findsNothing);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(signUps, 1);
    expect(recordings, 2);
    expect(requestIds.toSet(), hasLength(1));
    expect(verifications, 1);
  });

  testWidgets('Sign Up blocks duplicate keyboard and button submissions', (
    tester,
  ) async {
    final creation = Completer<void>();
    var signUps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          signUpHandler: (_, _) {
            signUps++;
            return creation.future;
          },
          ageEligibilityRecorder: (_) async {},
          emailVerificationSender: () async {},
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('auth-switch-mode')));
    await tester.tap(find.byKey(const Key('auth-switch-mode')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'new@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret12');
    await tester.ensureVisible(find.byKey(const Key('signup-age-checkbox')));
    await tester.tap(find.byKey(const Key('signup-age-checkbox')));
    await tester.pump();
    await tester.showKeyboard(find.byKey(const Key('auth-password')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    expect(signUps, 1);
    creation.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('account-key change invalidates session eligibility state', (
    tester,
  ) async {
    final first = _FakeEligibilityRepository(eligible: true);
    final second = _FakeEligibilityRepository();
    Widget gate(String uid, EligibilityRepository repository) => MaterialApp(
      home: AgeEligibilityGate(
        key: ValueKey(uid),
        repository: repository,
        eligibleBuilder: (_) => const Text('DESTINATION'),
      ),
    );
    await tester.pumpWidget(gate('uid-a', first));
    await tester.pumpAndSettle();
    expect(find.text('DESTINATION'), findsOneWidget);

    await tester.pumpWidget(gate('uid-b', second));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('age-eligibility-checkbox')), findsOneWidget);
    expect(first.getCalls, 1);
    expect(second.getCalls, 1);
  });

  testWidgets('valid eligibility bypasses the confirmation gate', (
    tester,
  ) async {
    final repository = _FakeEligibilityRepository(eligible: true);
    await tester.pumpWidget(
      MaterialApp(
        home: AgeEligibilityGate(
          repository: repository,
          eligibleBuilder: (_) => const Text('DESTINATION'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DESTINATION'), findsOneWidget);
    expect(find.byKey(const Key('age-eligibility-checkbox')), findsNothing);
    expect(repository.getCalls, 1);
  });

  testWidgets('missing eligibility requires an explicit unchecked assertion', (
    tester,
  ) async {
    final repository = _FakeEligibilityRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: AgeEligibilityGate(
          repository: repository,
          eligibleBuilder: (_) => const Text('DESTINATION'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const Key('age-eligibility-checkbox')),
    );
    expect(checkbox.value, isFalse);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('age-eligibility-continue')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('DESTINATION'), findsNothing);

    await tester.tap(find.byKey(const Key('age-eligibility-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('age-eligibility-continue')));
    await tester.pumpAndSettle();

    expect(repository.recordCalls, 1);
    expect(repository.requestIds.single, matches(RegExp(r'^[a-f0-9]{48}$')));
    expect(find.text('DESTINATION'), findsOneWidget);
  });

  testWidgets('record failure is sanitized and retries the same request', (
    tester,
  ) async {
    final repository = _FakeEligibilityRepository()
      ..recordError = StateError('sensitive backend detail');
    await tester.pumpWidget(
      MaterialApp(
        home: AgeEligibilityGate(
          repository: repository,
          eligibleBuilder: (_) => const Text('DESTINATION'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('age-eligibility-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('age-eligibility-continue')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not confirm eligibility'),
      findsOneWidget,
    );
    expect(find.textContaining('sensitive backend detail'), findsNothing);
    repository.recordError = null;
    await tester.tap(find.byKey(const Key('age-eligibility-continue')));
    await tester.pumpAndSettle();

    expect(repository.recordCalls, 2);
    expect(repository.requestIds.toSet(), hasLength(1));
    expect(find.text('DESTINATION'), findsOneWidget);
  });

  testWidgets('lookup failure fails closed and supports retry', (tester) async {
    final repository = _FakeEligibilityRepository(
      eligible: true,
      getError: StateError('private detail'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AgeEligibilityGate(
          repository: repository,
          eligibleBuilder: (_) => const Text('DESTINATION'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DESTINATION'), findsNothing);
    expect(find.text('Could not check age eligibility.'), findsOneWidget);
    expect(find.textContaining('private detail'), findsNothing);
    repository.getError = null;
    await tester.tap(find.byKey(const Key('age-eligibility-retry')));
    await tester.pumpAndSettle();
    expect(find.text('DESTINATION'), findsOneWidget);
  });

  testWidgets('eligibility layout survives narrow large text presentation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeEligibilityRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: AgeEligibilityScreen(
            repository: repository,
            onRecorded: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('18 years of age or older'), findsOneWidget);
  });
}
