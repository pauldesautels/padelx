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

  test('Functions setup failure is pre-call and never dispatches', () async {
    var callableInvocations = 0;
    final diagnostics = <String>[];

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
        diagnostic: diagnostics.add,
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
    expect(diagnostics, contains('functions-instance-success'));
    expect(diagnostics, isNot(contains('callable-created')));
    expect(diagnostics, isNot(contains('callable-dispatch-start')));
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
}
