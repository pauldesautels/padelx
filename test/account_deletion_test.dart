import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/main.dart';
import 'package:padelx/account_deletion.dart';

void main() {
  test('deleted player discards all legacy identifying fields', () {
    final player = MatchPlayer.fromMap({
      'deleted': true,
      'uid': 'old',
      'email': 'old@example.com',
      'displayName': 'Old name',
      'level': '5',
    });
    expect(player.uid, '');
    expect(player.email, '');
    expect(player.level, '');
    expect(player.displayName, 'Deleted player');
    final match = Match(
      id: 'm',
      title: '',
      club: '',
      level: '',
      spotsLeft: 0,
      creatorUid: '',
      creatorEmail: '',
      players: [player],
    );
    expect(ratingCandidates(match, 'viewer'), isEmpty);
  });
  testWidgets('deleted historical tile has no profile action or level', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfilePlayerTile(
            uid: '',
            fallbackName: 'Deleted player',
            fallbackLevel: '',
            role: 'Player',
          ),
        ),
      ),
    );
    expect(find.text('Deleted player'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
  });
  testWidgets('deletion confirmation explains consequences', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DeleteAccountScreen(onFinished: (_) async {})),
    );
    expect(find.text(deletionExplanation), findsOneWidget);
    expect(find.text('Permanently delete my account'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('empty password cannot submit deletion', (tester) async {
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DeleteAccountScreen(
          onFinished: (_) async {},
          submitDeletion: (_) async => submissions++,
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(submissions, 0);
  });

  testWidgets(
    'one captured password survives immediate clearing and completes',
    (tester) async {
      String? receivedPassword;
      String? finishedMessage;
      await tester.pumpWidget(
        MaterialApp(
          home: DeleteAccountScreen(
            onFinished: (message) async => finishedMessage = message,
            submitDeletion: (password) async {
              receivedPassword = password;
              expect(
                tester
                    .widget<TextField>(find.byType(TextField))
                    .controller!
                    .text,
                isEmpty,
              );
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'one-fresh-password');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(receivedPassword, 'one-fresh-password');
      expect(finishedMessage, contains('deletion requested'));
    },
  );

  testWidgets('failed attempt clears password and retry needs fresh input', (
    tester,
  ) async {
    final submittedPasswords = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DeleteAccountScreen(
          onFinished: (_) async {},
          submitDeletion: (password) async {
            submittedPasswords.add(password);
            throw const AccountDeletionFailure(
              AccountDeletionFailureKind.callable,
              'deadline-exceeded',
            );
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'first-password');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(submittedPasswords, ['first-password']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('may have been accepted'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fresh-password');
    await tester.pump();
    expect(find.textContaining('may have been accepted'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(submittedPasswords, ['first-password', 'fresh-password']);
  });

  testWidgets('screen recreation cannot reuse destructive confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeleteAccountScreen(
          onFinished: (_) async {},
          submitDeletion: (_) async {},
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'not-reusable');

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(
      MaterialApp(
        home: DeleteAccountScreen(
          onFinished: (_) async {},
          submitDeletion: (_) async {},
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
  test('errors distinguish credentials, rejection, and lost responses', () {
    expect(
      deletionReauthenticationErrorMessage('wrong-password'),
      contains('Incorrect password'),
    );
    expect(
      deletionCallableErrorMessage('failed-precondition'),
      contains('rejected'),
    );
    expect(
      deletionCallableErrorMessage('deadline-exceeded'),
      contains('may have been accepted'),
    );
    expect(deletionClientErrorMessage, contains('was not submitted'));
  });

  test('pre-call App Check failure never invokes the callable', () async {
    var callableInvocations = 0;

    await expectLater(
      runAccountDeletionFlow(
        reauthenticate: () async {},
        reloadUser: () async {},
        refreshIdToken: () async {},
        acquireAppCheckToken: () async => throw StateError('token failed'),
        initializeFunctions: () async {},
        createCallable: () async {},
        callDeletion: () async {
          callableInvocations++;
          return {'status': 'accepted'};
        },
      ),
      throwsA(
        isA<AccountDeletionFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              AccountDeletionFailureKind.preCall,
            )
            .having((failure) => failure.code, 'code', 'app-check-token')
            .having(
              (failure) => failure.userMessage,
              'message',
              contains('was not submitted'),
            ),
      ),
    );
    expect(callableInvocations, 0);
  });

  test('successful deletion flow requires reauthentication first', () async {
    final steps = <String>[];
    await runAccountDeletionFlow(
      reauthenticate: () async => steps.add('reauthenticate'),
      reloadUser: () async => steps.add('reload'),
      refreshIdToken: () async => steps.add('refresh'),
      acquireAppCheckToken: () async => steps.add('app-check'),
      initializeFunctions: () async => steps.add('functions'),
      createCallable: () async => steps.add('callable'),
      callDeletion: () async {
        steps.add('submit');
        return {'status': 'accepted'};
      },
    );

    expect(steps, [
      'reauthenticate',
      'reload',
      'refresh',
      'app-check',
      'functions',
      'callable',
      'submit',
    ]);
  });

  test('Functions setup failure is pre-call and never dispatches', () async {
    var callableInvocations = 0;

    await expectLater(
      runAccountDeletionFlow(
        reauthenticate: () async {},
        reloadUser: () async {},
        refreshIdToken: () async {},
        acquireAppCheckToken: () async {},
        initializeFunctions: () async {},
        createCallable: () async => throw StateError('setup failed'),
        callDeletion: () async {
          callableInvocations++;
          return {'status': 'accepted'};
        },
      ),
      throwsA(
        isA<AccountDeletionFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              AccountDeletionFailureKind.preCall,
            )
            .having((failure) => failure.code, 'code', 'functions-setup')
            .having(
              (failure) => failure.userMessage,
              'message',
              contains('was not submitted'),
            ),
      ),
    );
    expect(callableInvocations, 0);
  });

  test('lost callable response remains explicitly ambiguous', () async {
    await expectLater(
      runAccountDeletionFlow(
        reauthenticate: () async {},
        reloadUser: () async {},
        refreshIdToken: () async {},
        acquireAppCheckToken: () async {},
        initializeFunctions: () async {},
        createCallable: () async {},
        callDeletion: () async => throw FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: 'timed out',
        ),
      ),
      throwsA(
        isA<AccountDeletionFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              AccountDeletionFailureKind.callable,
            )
            .having(
              (failure) => failure.userMessage,
              'message',
              contains('may have been accepted'),
            ),
      ),
    );
  });

  test('raw callable client failure is not treated as accepted', () async {
    await expectLater(
      runAccountDeletionFlow(
        reauthenticate: () async {},
        reloadUser: () async {},
        refreshIdToken: () async {},
        acquireAppCheckToken: () async {},
        initializeFunctions: () async {},
        createCallable: () async {},
        callDeletion: () async => throw StateError('binding failed'),
      ),
      throwsA(
        isA<AccountDeletionFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              AccountDeletionFailureKind.preCall,
            )
            .having((failure) => failure.code, 'code', 'callable-client')
            .having(
              (failure) => failure.userMessage,
              'message',
              contains('was not submitted'),
            ),
      ),
    );
  });
}
