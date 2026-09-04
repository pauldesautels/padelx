import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const deletionExplanation =
    'Deletion is permanent. Future matches you organize '
    'will be cancelled, and you will leave future matches you joined. Historical '
    'participation will be anonymized. Ratings involving your account will be removed.';

const deletionClientErrorMessage =
    'Deletion was not submitted. Check your connection and app '
    'configuration, then try again.';

String deletionReauthenticationErrorMessage(String code) => switch (code) {
  'wrong-password' ||
  'invalid-credential' => 'Incorrect password. Please try again.',
  'network-request-failed' ||
  'unavailable' => 'Connection unavailable. Your password was not confirmed.',
  _ => 'Could not confirm your password. Please sign in again and retry.',
};

String deletionCallableErrorMessage(String code) => switch (code) {
  'deadline-exceeded' =>
    'The response was lost. Your request may have been accepted. Retrying is safe.',
  'unavailable' || 'network-request-failed' =>
    'Connection failed while submitting the request. Retrying is safe.',
  'failed-precondition' || 'requires-recent-login' =>
    'Account deletion was rejected. Please authenticate again or try later.',
  'user-disabled' || 'user-not-found' || 'unauthenticated' =>
    'Account deletion was rejected because this account is unavailable. Sign out; do not create a replacement profile.',
  'permission-denied' =>
    'Account deletion was rejected by the server. Please try again later.',
  _ =>
    'Account deletion was rejected or returned an invalid response. Retrying is safe.',
};

enum AccountDeletionFailureKind { reauthentication, preCall, callable }

class AccountDeletionFailure implements Exception {
  const AccountDeletionFailure(this.kind, this.code);

  final AccountDeletionFailureKind kind;
  final String code;

  String get userMessage => switch (kind) {
    AccountDeletionFailureKind.reauthentication =>
      deletionReauthenticationErrorMessage(code),
    AccountDeletionFailureKind.preCall => deletionClientErrorMessage,
    AccountDeletionFailureKind.callable => deletionCallableErrorMessage(code),
  };
}

typedef DeletionStep = Future<void> Function();
typedef DeletionCall = Future<Map<String, dynamic>> Function();
typedef DeletionDiagnostic = void Function(String stage);

void debugDeletionDiagnostic(String stage) {
  if (kDebugMode) debugPrint('account-deletion: $stage');
}

Future<void> runAccountDeletionFlow({
  required DeletionStep reauthenticate,
  required DeletionStep reloadUser,
  required DeletionStep refreshIdToken,
  required DeletionStep acquireAppCheckToken,
  required DeletionStep initializeFunctions,
  required DeletionStep createCallable,
  required DeletionCall callDeletion,
  DeletionDiagnostic diagnostic = debugDeletionDiagnostic,
}) async {
  diagnostic('reauth-start');
  try {
    await reauthenticate();
    diagnostic('reauth-success');
  } on FirebaseException catch (error) {
    diagnostic('reauth-failure');
    throw AccountDeletionFailure(
      AccountDeletionFailureKind.reauthentication,
      error.code,
    );
  } catch (_) {
    diagnostic('reauth-failure');
    throw const AccountDeletionFailure(
      AccountDeletionFailureKind.reauthentication,
      'unknown',
    );
  }

  try {
    await reloadUser();
    diagnostic('reload-success');
    await refreshIdToken();
    diagnostic('token-refresh-success');
  } catch (_) {
    throw const AccountDeletionFailure(
      AccountDeletionFailureKind.preCall,
      'id-token-refresh',
    );
  }

  diagnostic('appcheck-start');
  try {
    await acquireAppCheckToken();
    diagnostic('appcheck-success');
  } catch (_) {
    diagnostic('appcheck-failure');
    throw const AccountDeletionFailure(
      AccountDeletionFailureKind.preCall,
      'app-check-token',
    );
  }

  try {
    await initializeFunctions();
    diagnostic('functions-instance-success');
    await createCallable();
    diagnostic('callable-created');
  } catch (_) {
    throw const AccountDeletionFailure(
      AccountDeletionFailureKind.preCall,
      'functions-setup',
    );
  }

  diagnostic('callable-dispatch-start');
  try {
    final receipt = await callDeletion();
    diagnostic('callable-response');
    if (receipt['status'] != 'accepted') {
      throw const AccountDeletionFailure(
        AccountDeletionFailureKind.callable,
        'invalid-response',
      );
    }
  } on AccountDeletionFailure {
    rethrow;
  } on FirebaseFunctionsException catch (error) {
    diagnostic('callable-error');
    throw AccountDeletionFailure(
      AccountDeletionFailureKind.callable,
      error.code,
    );
  } catch (_) {
    diagnostic('callable-error');
    throw const AccountDeletionFailure(
      AccountDeletionFailureKind.callable,
      'unknown',
    );
  }
}

class DeleteAccountScreen extends StatefulWidget {
  final Future<void> Function(String message) onFinished;
  const DeleteAccountScreen({super.key, required this.onFinished});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');
      if (!user.providerData.any(
            (provider) => provider.providerId == 'password',
          ) ||
          user.email == null) {
        setState(() {
          _error =
              'Sign in again with your account provider before requesting deletion. This screen currently supports password accounts.';
          _busy = false;
        });
        return;
      }
      late FirebaseFunctions functions;
      late HttpsCallable callable;
      await runAccountDeletionFlow(
        reauthenticate: () async {
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: user.email!,
              password: _password.text,
            ),
          );
        },
        reloadUser: () async {
          _password.clear();
          await user.reload();
        },
        refreshIdToken: () async {
          final refreshedUser = FirebaseAuth.instance.currentUser;
          if (refreshedUser == null) {
            throw StateError('Auth session disappeared after reauthentication');
          }
          await refreshedUser.getIdToken(true);
        },
        acquireAppCheckToken: () async {
          final token = await FirebaseAppCheck.instance.getToken(false);
          if (token == null || token.isEmpty) {
            throw StateError('App Check did not provide a token');
          }
        },
        initializeFunctions: () async {
          functions = FirebaseFunctions.instanceFor(
            app: Firebase.app(),
            region: 'us-central1',
          );
        },
        createCallable: () async {
          callable = functions.httpsCallable(
            'requestAccountDeletion',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          );
        },
        callDeletion: () async {
          final result = await callable.call<Map<String, dynamic>>();
          return result.data;
        },
      );
      await widget.onFinished(
        'Account deletion requested. You are signed out. Cleanup continues securely in the background.',
      );
    } on AccountDeletionFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) setState(() => _error = deletionClientErrorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Delete Account'),
      automaticallyImplyLeading: false,
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(deletionExplanation),
              const SizedBox(height: 24),
              TextField(
                controller: _password,
                obscureText: true,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Confirm your password',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_error!, semanticsLabel: _error),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _delete,
                child: Text(
                  _busy
                      ? 'Requesting deletion…'
                      : 'Permanently delete my account',
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => widget.onFinished('You are signed out.'),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
