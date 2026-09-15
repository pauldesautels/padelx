import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'branding.dart';
import 'account_access.dart';
import 'l10n/l10n.dart';

const ageEligibilityVersion = '18-plus-v1';

String newEligibilityRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

abstract class EligibilityRepository {
  Future<bool> getEligibility();
  Future<void> recordEligibility({required String requestId});

  factory EligibilityRepository.firebase() = FirebaseEligibilityRepository;
}

class FirebaseEligibilityRepository implements EligibilityRepository {
  final FirebaseFunctions functions;

  FirebaseEligibilityRepository({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<bool> getEligibility() async {
    late HttpsCallableResult<dynamic> result;
    try {
      result = await functions.httpsCallable('getAgeEligibility').call();
    } catch (error) {
      signalAccountAccessRestriction(error);
      rethrow;
    }
    final data = result.data;
    return data is Map &&
        data['eligible'] == true &&
        data['version'] == ageEligibilityVersion;
  }

  @override
  Future<void> recordEligibility({required String requestId}) async {
    late HttpsCallableResult<dynamic> result;
    try {
      result = await functions.httpsCallable('recordAgeEligibility').call({
        'confirmed': true,
        'version': ageEligibilityVersion,
        'requestId': requestId,
      });
    } catch (error) {
      signalAccountAccessRestriction(error);
      rethrow;
    }
    final data = result.data;
    if (data is! Map ||
        data['recorded'] != true ||
        data['version'] != ageEligibilityVersion) {
      throw const FormatException('Invalid eligibility response.');
    }
  }
}

class AgeEligibilityGate extends StatefulWidget {
  final EligibilityRepository repository;
  final WidgetBuilder eligibleBuilder;
  final Future<void> Function()? onSignOut;

  const AgeEligibilityGate({
    super.key,
    required this.repository,
    required this.eligibleBuilder,
    this.onSignOut,
  });

  @override
  State<AgeEligibilityGate> createState() => _AgeEligibilityGateState();
}

class _AgeEligibilityGateState extends State<AgeEligibilityGate> {
  late Future<bool> _eligibility;

  @override
  void initState() {
    super.initState();
    _eligibility = widget.repository.getEligibility();
  }

  void _retry() => setState(() {
    _eligibility = widget.repository.getEligibility();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _eligibility,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _EligibilityLoadingScreen();
      }
      if (snapshot.hasError) {
        return EligibilityLoadErrorScreen(
          onRetry: _retry,
          onSignOut: widget.onSignOut,
        );
      }
      if (snapshot.data != true) {
        return AgeEligibilityScreen(
          repository: widget.repository,
          onRecorded: _retry,
          onSignOut: widget.onSignOut,
        );
      }
      return widget.eligibleBuilder(context);
    },
  );
}

class _EligibilityLoadingScreen extends StatelessWidget {
  const _EligibilityLoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: padelXBackground,
    body: Center(child: CircularProgressIndicator()),
  );
}

class AgeEligibilityScreen extends StatefulWidget {
  final EligibilityRepository repository;
  final VoidCallback onRecorded;
  final Future<void> Function()? onSignOut;

  const AgeEligibilityScreen({
    super.key,
    required this.repository,
    required this.onRecorded,
    this.onSignOut,
  });

  @override
  State<AgeEligibilityScreen> createState() => _AgeEligibilityScreenState();
}

class _AgeEligibilityScreenState extends State<AgeEligibilityScreen> {
  bool _confirmed = false;
  bool _busy = false;
  String? _error;
  late final String _requestId = newEligibilityRequestId();

  Future<void> _continue() async {
    if (!_confirmed || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.recordEligibility(requestId: _requestId);
      if (mounted) widget.onRecorded();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.eligibilityConfirmFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: padelXBackground,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: padelXSurface,
                border: Border.all(color: padelXAuthBorder),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PadelXBrandMark(size: 64),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.adultOnly,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.ageRequired,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      key: const Key('age-eligibility-checkbox'),
                      value: _confirmed,
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _confirmed = value == true),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(context.l10n.ageConfirmation),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        key: const Key('age-eligibility-error'),
                        style: const TextStyle(color: Color(0xFFFFA59C)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const Key('age-eligibility-continue'),
                      onPressed: _confirmed && !_busy ? _continue : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: padelXAuthPrimary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _busy
                            ? context.l10n.confirmingEllipsis
                            : context.l10n.continueLabel,
                      ),
                    ),
                  ),
                  if (widget.onSignOut != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('age-eligibility-sign-out'),
                      onPressed: _busy ? null : widget.onSignOut,
                      child: Text(context.l10n.signOut),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class EligibilityLoadErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final Future<void> Function()? onSignOut;

  const EligibilityLoadErrorScreen({
    super.key,
    required this.onRetry,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: padelXBackground,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              context.l10n.ageCheckFailed,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.connectionRetry, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('age-eligibility-retry'),
              onPressed: onRetry,
              child: Text(context.l10n.tryAgain),
            ),
            if (onSignOut != null)
              TextButton(
                key: const Key('age-eligibility-error-sign-out'),
                onPressed: onSignOut,
                child: Text(context.l10n.signOut),
              ),
          ],
        ),
      ),
    ),
  );
}
