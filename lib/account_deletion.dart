import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const _deletionDiagnosticsEnabled =
    bool.fromEnvironment('PADELX_DELETION_DIAGNOSTICS') &&
    String.fromEnvironment('FIREBASE_ENVIRONMENT') == 'staging';

void _deletionDiagnostic(String stage, [Object? error]) {
  if (!_deletionDiagnosticsEnabled) return;
  final type = error?.runtimeType;
  final code =
      error is FirebaseException &&
          RegExp(r'^[a-z0-9-]{1,64}$').hasMatch(error.code)
      ? error.code
      : null;
  debugPrint(
    'account-deletion-diagnostic stage=$stage'
    '${type == null ? '' : ' type=$type'}'
    '${code == null ? '' : ' code=$code'}',
  );
}

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
    'The connection was lost while submitting. Your request may have been accepted. Retrying is safe.',
  'failed-precondition' || 'requires-recent-login' =>
    'Account deletion was rejected. Please authenticate again or try later.',
  'user-disabled' || 'user-not-found' || 'unauthenticated' =>
    'Account deletion was rejected because this account is unavailable. Sign out; do not create a replacement profile.',
  'permission-denied' =>
    'Account deletion was rejected by the server. Please try again later.',
  'invalid-response' =>
    'The server response was invalid. Your request may have been accepted. Retrying is safe.',
  _ =>
    'The result could not be confirmed. Your request may have been accepted. Retrying is safe.',
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
Future<void> runAccountDeletionFlow({
  required DeletionStep reauthenticate,
  required DeletionStep reloadUser,
  required DeletionStep refreshIdToken,
  required DeletionStep acquireAppCheckToken,
  required DeletionStep initializeFunctions,
  required DeletionStep createCallable,
  required DeletionCall callDeletion,
}) async {
  try {
    await reauthenticate();
  } on FirebaseException catch (error) {
    throw AccountDeletionFailure(
      AccountDeletionFailureKind.reauthentication,
      error.code,
    );
  } catch (_) {
    throw const AccountDeletionFailure(
      AccountDeletionFailureKind.reauthentication,
      'unknown',
    );
  }

  try {
    await reloadUser();
    await refreshIdToken();
  } catch (_) {
    throw const AccountDeletionFailure(
      AccountDeletionFailureKind.preCall,
      'id-token-refresh',
    );
  }

  try {
    await acquireAppCheckToken();
    _deletionDiagnostic('app-check-token-ready');
  } catch (error) {
    _deletionDiagnostic('app-check-token-failed', error);
    throw const AccountDeletionFailure(
      AccountDeletionFailureKind.preCall,
      'app-check-token',
    );
  }

  try {
    await initializeFunctions();
    await createCallable();
    _deletionDiagnostic('callable-created');
  } catch (error) {
    _deletionDiagnostic('callable-setup-failed', error);
    throw const AccountDeletionFailure(
      AccountDeletionFailureKind.preCall,
      'functions-setup',
    );
  }

  try {
    _deletionDiagnostic('callable-invocation-started');
    final receipt = await callDeletion();
    if (receipt['status'] != 'accepted') {
      throw const AccountDeletionFailure(
        AccountDeletionFailureKind.callable,
        'invalid-response',
      );
    }
  } on AccountDeletionFailure {
    rethrow;
  } on FirebaseFunctionsException catch (error) {
    _deletionDiagnostic('callable-firebase-error', error);
    throw AccountDeletionFailure(
      AccountDeletionFailureKind.callable,
      error.code,
    );
  } catch (error) {
    // The web binding converts normal callable failures, including server
    // errors and transport failures, to FirebaseFunctionsException. A raw
    // Dart/JS exception means the client invocation machinery itself failed;
    // it is not evidence that the callable request crossed the network.
    _deletionDiagnostic('callable-client-failed', error);
    throw const AccountDeletionFailure(
      AccountDeletionFailureKind.preCall,
      'callable-client',
    );
  }
}

class DeleteAccountScreen extends StatefulWidget {
  final Future<void> Function(String message) onFinished;
  final Future<void> Function(String password)? submitDeletion;
  const DeleteAccountScreen({
    super.key,
    required this.onFinished,
    this.submitDeletion,
  });
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _freshPasswordEntered = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy || !_freshPasswordEntered || _password.text.isEmpty) {
      setState(() {
        _error = 'Enter your password for this deletion attempt.';
      });
      return;
    }

    // A destructive confirmation is single-use. Invalidate and remove it
    // before the first await so failures and retries always require new input.
    final password = _password.text;
    _password.clear();
    setState(() {
      _busy = true;
      _freshPasswordEntered = false;
      _error = null;
    });
    try {
      await (widget.submitDeletion ?? _submitDeletion)(password);
      await widget.onFinished(
        'Account deletion requested. You are signed out. Cleanup continues securely in the background.',
      );
    } on AccountDeletionFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) setState(() => _error = deletionClientErrorMessage);
    } finally {
      _password.clear();
      if (mounted) {
        setState(() {
          _busy = false;
          _freshPasswordEntered = false;
        });
      }
    }
  }

  Future<void> _submitDeletion(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');
    if (!user.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ||
        user.email == null) {
      throw const AccountDeletionFailure(
        AccountDeletionFailureKind.preCall,
        'unsupported-provider',
      );
    }
    late FirebaseFunctions functions;
    late HttpsCallable callable;
    await runAccountDeletionFlow(
      reauthenticate: () async {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
      },
      reloadUser: () async {
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
        final token = await FirebaseAppCheck.instance.getToken(true);
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
                autofillHints: const <String>[],
                onChanged: (value) {
                  setState(() {
                    _freshPasswordEntered = value.isNotEmpty;
                    if (value.isNotEmpty) _error = null;
                  });
                },
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
                onPressed: _busy || !_freshPasswordEntered ? null : _delete,
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
