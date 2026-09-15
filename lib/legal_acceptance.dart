import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'account_access.dart';
import 'branding.dart';
import 'legal.dart';
import 'l10n/l10n.dart';

String newLegalRequestId() {
  final random = Random.secure();
  return List<int>.generate(
    24,
    (_) => random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

abstract class LegalAcceptanceRepository {
  Future<bool> getAcceptance();
  Future<void> recordAcceptance({required String requestId});
  factory LegalAcceptanceRepository.firebase() =
      FirebaseLegalAcceptanceRepository;
}

class FirebaseLegalAcceptanceRepository implements LegalAcceptanceRepository {
  final FirebaseFunctions functions;
  FirebaseLegalAcceptanceRepository({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;
  @override
  Future<bool> getAcceptance() async {
    try {
      final result = await functions.httpsCallable('getLegalAcceptance').call();
      final data = result.data;
      return data is Map &&
          data['accepted'] == true &&
          data['termsVersion'] == PadelXLegalConfiguration.beta.termsVersion &&
          data['privacyVersion'] ==
              PadelXLegalConfiguration.beta.privacyVersion &&
          data['communityVersion'] ==
              PadelXLegalConfiguration.beta.communityVersion;
    } catch (error) {
      signalAccountAccessRestriction(error);
      rethrow;
    }
  }

  @override
  Future<void> recordAcceptance({required String requestId}) async {
    try {
      final c = PadelXLegalConfiguration.beta;
      final result = await functions
          .httpsCallable('recordLegalAcceptance')
          .call({
            'acknowledged': true,
            'termsVersion': c.termsVersion,
            'privacyVersion': c.privacyVersion,
            'communityVersion': c.communityVersion,
            'requestId': requestId,
          });
      if (result.data is! Map || result.data['recorded'] != true) {
        throw const FormatException('Invalid legal acceptance response.');
      }
    } catch (error) {
      signalAccountAccessRestriction(error);
      rethrow;
    }
  }
}

class LegalAcceptanceGate extends StatefulWidget {
  final LegalAcceptanceRepository repository;
  final WidgetBuilder acceptedBuilder;
  final Future<void> Function()? onSignOut;
  const LegalAcceptanceGate({
    super.key,
    required this.repository,
    required this.acceptedBuilder,
    this.onSignOut,
  });
  @override
  State<LegalAcceptanceGate> createState() => _LegalAcceptanceGateState();
}

class _LegalAcceptanceGateState extends State<LegalAcceptanceGate> {
  late Future<bool> _accepted = widget.repository.getAcceptance();

  Future<void> _recheckAfterRecord() async {
    final accepted = await widget.repository.getAcceptance();
    if (!accepted) {
      throw StateError('Legal acceptance was not confirmed.');
    }
    if (mounted) {
      setState(() {
        _accepted = Future<bool>.value(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _accepted,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          backgroundColor: padelXBackground,
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.data == true) {
        return widget.acceptedBuilder(context);
      }
      return LegalAcceptanceScreen(
        repository: widget.repository,
        onAccepted: _recheckAfterRecord,
        onSignOut: widget.onSignOut,
        loadFailed: snapshot.hasError,
      );
    },
  );
}

class LegalAcceptanceScreen extends StatefulWidget {
  final LegalAcceptanceRepository repository;
  final Future<void> Function() onAccepted;
  final Future<void> Function()? onSignOut;
  final bool loadFailed;
  const LegalAcceptanceScreen({
    super.key,
    required this.repository,
    required this.onAccepted,
    this.onSignOut,
    this.loadFailed = false,
  });
  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  bool agreed = false, busy = false;
  String? error;
  late final requestId = newLegalRequestId();
  Future<void> submit() async {
    if (!agreed || busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.recordAcceptance(requestId: requestId);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = context.l10n.legalRecordFailed;
        });
      }
      return;
    }
    try {
      await widget.onAccepted();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = context.l10n.legalRefreshFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: padelXBackground,
    appBar: AppBar(title: Text(context.l10n.legalAcknowledgement)),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.l10n.beforeContinuing,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.legalReviewIntro,
          style: TextStyle(color: Colors.white70),
        ),
        TextButton(
          onPressed: () => openLegalLink(context, '/terms'),
          child: Text(context.l10n.termsOfUse),
        ),
        TextButton(
          onPressed: () => openLegalLink(context, '/privacy'),
          child: Text(context.l10n.privacyPolicy),
        ),
        CheckboxListTile(
          key: const Key('legal-acceptance-checkbox'),
          value: agreed,
          onChanged: busy
              ? null
              : (value) => setState(() => agreed = value == true),
          title: Text(context.l10n.legalAgreement),
        ),
        if (widget.loadFailed)
          Text(
            context.l10n.legalLoadFailed,
            style: TextStyle(color: Colors.orangeAccent),
          ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.redAccent)),
        FilledButton(
          key: const Key('legal-acceptance-continue'),
          onPressed: agreed && !busy ? submit : null,
          child: Text(
            busy ? context.l10n.savingEllipsis : context.l10n.continueLabel,
          ),
        ),
        if (widget.onSignOut != null)
          TextButton(
            onPressed: busy ? null : widget.onSignOut,
            child: Text(context.l10n.signOut),
          ),
      ],
    ),
  );
}
