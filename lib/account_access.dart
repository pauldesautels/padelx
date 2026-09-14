import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'branding.dart';
import 'safety_policy.dart';

final _accountAccessRefreshController = StreamController<void>.broadcast();

void signalAccountAccessRestriction(Object error) {
  if (error is FirebaseFunctionsException &&
      error.code == 'permission-denied' &&
      error.message == 'Account access is restricted.') {
    _accountAccessRefreshController.add(null);
  }
}

class AccountAccessState {
  final bool restricted;
  final String? status;
  final String? reasonCategory;
  final DateTime? expiresAt;

  const AccountAccessState({
    required this.restricted,
    this.status,
    this.reasonCategory,
    this.expiresAt,
  });

  factory AccountAccessState.fromMap(Map<dynamic, dynamic> data) {
    final rawExpiry = data['expiresAt'];
    final expiry = rawExpiry is Timestamp
        ? rawExpiry.toDate()
        : rawExpiry is DateTime
        ? rawExpiry
        : null;
    final restricted = data['restricted'] == true;
    final status = data['status']?.toString();
    if (!restricted) return const AccountAccessState(restricted: false);
    if (!{'suspended', 'banned'}.contains(status)) {
      return const AccountAccessState(
        restricted: true,
        status: 'banned',
        reasonCategory: 'other_policy_violation',
      );
    }
    return AccountAccessState(
      restricted: true,
      status: status,
      reasonCategory: data['reasonCategory']?.toString(),
      expiresAt: status == 'suspended' ? expiry : null,
    );
  }
}

abstract class AccountAccessRepository {
  Future<AccountAccessState> load();
}

class FirebaseAccountAccessRepository implements AccountAccessRepository {
  final FirebaseFunctions functions;
  FirebaseAccountAccessRepository({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<AccountAccessState> load() async {
    final result = await functions
        .httpsCallable('getAccountAccessState')
        .call();
    return AccountAccessState.fromMap(
      Map<dynamic, dynamic>.from(result.data as Map),
    );
  }
}

class AccountAccessGate extends StatefulWidget {
  final String uid;
  final AccountAccessRepository repository;
  final WidgetBuilder allowedBuilder;
  final VoidCallback onDeleteAccount;
  final Future<void> Function() onSignOut;
  final SupportUriLauncher supportLauncher;

  const AccountAccessGate({
    super.key,
    required this.uid,
    required this.repository,
    required this.allowedBuilder,
    required this.onDeleteAccount,
    required this.onSignOut,
    this.supportLauncher = launchSupportUri,
  });

  @override
  State<AccountAccessGate> createState() => _AccountAccessGateState();
}

class _AccountAccessGateState extends State<AccountAccessGate>
    with WidgetsBindingObserver {
  AccountAccessState? _state;
  Object? _error;
  bool _loading = false;
  bool _refreshQueued = false;
  int _generation = 0;
  Timer? _expiryTimer;
  StreamSubscription<void>? _restrictionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restrictionSubscription = _accountAccessRefreshController.stream.listen(
      (_) => unawaited(_refresh()),
    );
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(AccountAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.repository != widget.repository) {
      _generation++;
      _expiryTimer?.cancel();
      _state = null;
      _error = null;
      unawaited(_refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_loading) {
      _refreshQueued = true;
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await widget.repository.load();
      if (!mounted || generation != _generation) return;
      _expiryTimer?.cancel();
      final expiry = state.expiresAt;
      if (state.restricted && expiry != null) {
        final delay = expiry.difference(DateTime.now());
        _expiryTimer = Timer(
          delay.isNegative ? Duration.zero : delay,
          () => unawaited(_refresh()),
        );
      }
      setState(() => _state = state);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        if (_refreshQueued) {
          _refreshQueued = false;
          unawaited(_refresh());
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    _restrictionSubscription?.cancel();
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) {
      if (_error != null) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not verify account access.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _refresh,
                    child: const Text('Try Again'),
                  ),
                  TextButton(
                    onPressed: _loading ? null : widget.onSignOut,
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.restricted) return widget.allowedBuilder(context);
    return RestrictedAccountScreen(
      state: state,
      onRetry: _refresh,
      onDeleteAccount: widget.onDeleteAccount,
      onSignOut: widget.onSignOut,
      supportLauncher: widget.supportLauncher,
    );
  }
}

class RestrictedAccountScreen extends StatelessWidget {
  final AccountAccessState state;
  final Future<void> Function() onRetry;
  final VoidCallback onDeleteAccount;
  final Future<void> Function() onSignOut;
  final SupportUriLauncher supportLauncher;

  const RestrictedAccountScreen({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onDeleteAccount,
    required this.onSignOut,
    this.supportLauncher = launchSupportUri,
  });

  String get _reason => switch (state.reasonCategory) {
    'harassment_abuse' => 'Harassment or abusive conduct',
    'hate_discrimination' => 'Hate or discriminatory conduct',
    'sexual_misconduct' => 'Sexual or inappropriate conduct',
    'threats_unsafe_behavior' => 'Threats or unsafe behavior',
    'spam_scam' => 'Spam or scams',
    'impersonation' => 'Impersonation',
    'privacy_violation' => 'Privacy violation',
    'fraud_deception' => 'Fraud or deception',
    'malicious_reporting' => 'Misuse of reporting',
    _ => 'Community Guidelines',
  };

  Future<void> _contact(BuildContext context) async {
    final uri = PadelXSupportConfiguration.beta.mailtoUri;
    final opened = uri != null && await supportLauncher(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open email. Contact support.padelx@gmail.com.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final suspended = state.status == 'suspended';
    final expiry = state.expiresAt;
    final localExpiry = expiry?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final expiryText = localExpiry == null
        ? null
        : '${localizations.formatFullDate(localExpiry)} at '
              '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(localExpiry))}';
    return Scaffold(
      backgroundColor: padelXBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            container: true,
            label: suspended
                ? 'Account temporarily suspended'
                : 'Account restricted',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Icon(
                  Icons.shield_outlined,
                  size: 56,
                  color: padelXAccent,
                ),
                const SizedBox(height: 24),
                Text(
                  suspended
                      ? 'Account temporarily suspended'
                      : 'Account restricted',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  suspended
                      ? 'Your access to PadelX has been temporarily restricted.'
                      : 'Your access to PadelX has been restricted.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Policy category',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(_reason),
                        if (suspended && expiryText != null) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Restriction ends',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(expiryText),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _contact(context),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Contact PadelX Support'),
                ),
                OutlinedButton(
                  onPressed: onDeleteAccount,
                  child: const Text('Delete Account'),
                ),
                TextButton(onPressed: onSignOut, child: const Text('Sign Out')),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Check access again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
