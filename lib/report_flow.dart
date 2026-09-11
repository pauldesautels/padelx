import 'package:flutter/material.dart';

import 'report_repository.dart';
import 'reporting.dart';

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
      title: const Text('Report submitted'),
      content: const Text('Thanks for helping keep PadelX safe.'),
      actions: [
        TextButton(
          key: const Key('report-success-done'),
          onPressed: () => Navigator.pop(successContext, 'done'),
          child: const Text('Done'),
        ),
        if (onBlockPlayer != null)
          FilledButton(
            key: const Key('report-success-block'),
            onPressed: () => Navigator.pop(successContext, 'block'),
            child: const Text('Block player'),
          ),
      ],
    ),
  );
  if (action != 'block' || onBlockPlayer == null || !context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (confirmationContext) => AlertDialog(
      title: const Text('Block this player?'),
      content: Text(
        sharedMatchBlockCopy
            ? 'Blocking prevents normal social discovery and contact. Shared-match access still follows match membership.'
            : friendshipWillBeRemoved
            ? 'Your friendship will be removed and normal social discovery and contact will be prevented. Shared-match access still follows match membership.'
            : 'Normal social discovery and contact with this player will be prevented. Shared-match access still follows match membership.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(confirmationContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-report-block'),
          onPressed: () => Navigator.pop(confirmationContext, true),
          child: const Text('Block player'),
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
      ).showSnackBar(const SnackBar(content: Text('Player blocked.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player could not be blocked.')),
      );
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

  String get _subjectName => switch (widget.subjectType) {
    ReportSubjectType.player => 'player',
    ReportSubjectType.message => 'message',
    ReportSubjectType.match => 'match',
  };

  String get _failureMessage => switch (_failure) {
    ReportFailureKind.alreadyReported => 'You already reported this.',
    ReportFailureKind.rateLimited =>
      'You’ve submitted several reports recently. Please try again later.',
    ReportFailureKind.generic ||
    null => 'Report could not be submitted. Please try again.',
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
    title: Text('Report $_subjectName'),
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
            const Text('Why are you reporting this?'),
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
                        title: Text(reason.label),
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
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_failure != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _failureMessage,
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
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('submit-report'),
        onPressed: _reason == null || _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Submit'),
      ),
    ],
  );
}
