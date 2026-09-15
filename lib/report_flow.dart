import 'package:flutter/material.dart';

import 'report_repository.dart';
import 'reporting.dart';
import 'l10n/l10n.dart';

const reportDetailsLimit = 500;

Future<void> showReportFlow({
  required BuildContext context,
  required ReportRepository repository,
  required ReportSubjectType subjectType,
  required String subjectId,
  String? conversationId,
  String? subjectLabel,
  Future<void> Function()? onBlockPlayer,
  bool sharedMatchBlockCopy = false,
  bool friendshipWillBeRemoved = false,
}) async {
  final requestId = newReportRequestId();
  final submitted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReportDialog(
      repository: repository,
      requestId: requestId,
      subjectType: subjectType,
      subjectId: subjectId,
      conversationId: conversationId,
      subjectLabel: subjectLabel,
    ),
  );
  if (submitted != true || !context.mounted) return;
  final action = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (successContext) => AlertDialog(
      key: const Key('report-success-dialog'),
      title: Text(context.l10n.reportSubmitted),
      content: Text(context.l10n.thanksForSafety),
      actions: [
        TextButton(
          key: const Key('report-success-done'),
          onPressed: () => Navigator.pop(successContext, 'done'),
          child: Text(context.l10n.done),
        ),
        if (onBlockPlayer != null)
          FilledButton(
            key: const Key('report-success-block'),
            onPressed: () => Navigator.pop(successContext, 'block'),
            child: Text(context.l10n.blockPlayer),
          ),
      ],
    ),
  );
  if (action != 'block' || onBlockPlayer == null || !context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (confirmationContext) => AlertDialog(
      title: Text(context.l10n.blockThisPlayer),
      content: Text(
        sharedMatchBlockCopy
            ? context.l10n.sharedMatchBlockExplanation
            : friendshipWillBeRemoved
            ? context.l10n.friendBlockExplanation
            : context.l10n.nonFriendBlockExplanation,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(confirmationContext, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-report-block'),
          onPressed: () => Navigator.pop(confirmationContext, true),
          child: Text(context.l10n.blockPlayer),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await onBlockPlayer();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.playerBlocked)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.playerBlockFailed)));
    }
  }
}

class ReportDialog extends StatefulWidget {
  final ReportRepository repository;
  final String requestId;
  final ReportSubjectType subjectType;
  final String subjectId;
  final String? conversationId;
  final String? subjectLabel;

  const ReportDialog({
    super.key,
    required this.repository,
    required this.requestId,
    required this.subjectType,
    required this.subjectId,
    this.conversationId,
    this.subjectLabel,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _details = TextEditingController();
  ReportReason? _reason;
  ReportFailureKind? _failure;
  bool _submitting = false;

  String _subjectName(BuildContext context) => switch (widget.subjectType) {
    ReportSubjectType.player => context.l10n.player.toLowerCase(),
    ReportSubjectType.message => context.l10n.message.toLowerCase(),
    ReportSubjectType.match => context.l10n.matches.toLowerCase(),
  };

  String _failureMessage(BuildContext context) => switch (_failure) {
    ReportFailureKind.alreadyReported => context.l10n.reportAlreadySubmitted,
    ReportFailureKind.rateLimited => context.l10n.reportRateLimited,
    ReportFailureKind.generic || null => context.l10n.reportFailed,
  };

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null || _submitting) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      final receipt = await widget.repository.submit(
        ReportRequest(
          requestId: widget.requestId,
          subjectType: widget.subjectType,
          subjectId: widget.subjectId,
          conversationId: widget.conversationId,
          reason: _reason!,
          details: _details.text,
        ),
      );
      if (!mounted) return;
      if (receipt.submitted) {
        Navigator.pop(context, true);
      } else {
        setState(() => _failure = ReportFailureKind.generic);
      }
    } on ReportFailure catch (error) {
      if (mounted) setState(() => _failure = error.kind);
    } catch (_) {
      if (mounted) setState(() => _failure = ReportFailureKind.generic);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('report-dialog'),
    title: Text(context.l10n.reportSubject(_subjectName(context))),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.subjectLabel?.isNotEmpty == true) ...[
              Text(
                widget.subjectLabel!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],
            Text(context.l10n.whyReporting),
            const SizedBox(height: 4),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: _submitting
                  ? (_) {}
                  : (value) => setState(() {
                      _reason = value;
                      _failure = null;
                    }),
              child: Column(
                children: ReportReason.values
                    .map(
                      (reason) => RadioListTile<ReportReason>(
                        key: Key('report-reason-${reason.value}'),
                        value: reason,
                        contentPadding: EdgeInsets.zero,
                        title: Text(switch (reason) {
                          ReportReason.harassmentBullying =>
                            context.l10n.harassmentBullying,
                          ReportReason.hateAbuse => context.l10n.hateAbuse,
                          ReportReason.sexualInappropriate =>
                            context.l10n.sexualInappropriate,
                          ReportReason.threatsUnsafeBehavior =>
                            context.l10n.threatsUnsafe,
                          ReportReason.spamScam => context.l10n.spamScam,
                          ReportReason.impersonation =>
                            context.l10n.impersonation,
                          ReportReason.other => context.l10n.other,
                        }),
                        enabled: !_submitting,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('report-details'),
              controller: _details,
              enabled: !_submitting,
              maxLength: reportDetailsLimit,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                labelText: context.l10n.additionalDetails,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_failure != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _failureMessage(context),
                  key: const Key('report-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('cancel-report'),
        onPressed: _submitting ? null : () => Navigator.pop(context, false),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('submit-report'),
        onPressed: _reason == null || _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(context.l10n.submit),
      ),
    ],
  );
}
