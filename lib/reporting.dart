import 'dart:math';

enum ReportSubjectType { player, message, match }

enum ReportReason {
  harassmentBullying('harassment_bullying', 'Harassment or bullying'),
  hateAbuse('hate_abuse', 'Hate or abusive content'),
  sexualInappropriate(
    'sexual_inappropriate',
    'Sexual or inappropriate content',
  ),
  threatsUnsafeBehavior(
    'threats_unsafe_behavior',
    'Threats or unsafe behavior',
  ),
  spamScam('spam_scam', 'Spam or scam'),
  impersonation('impersonation', 'Impersonation'),
  other('other', 'Other');

  final String value;
  final String label;
  const ReportReason(this.value, this.label);
}

class ReportRequest {
  final String requestId;
  final ReportSubjectType subjectType;
  final String subjectId;
  final String? conversationId;
  final ReportReason reason;
  final String? details;

  const ReportRequest({
    required this.requestId,
    required this.subjectType,
    required this.subjectId,
    this.conversationId,
    required this.reason,
    this.details,
  });

  Map<String, Object> toMap() => {
    'requestId': requestId,
    'subjectType': subjectType.name,
    'subjectId': subjectId,
    'conversationId': ?conversationId,
    'reason': reason.value,
    if (details?.trim().isNotEmpty == true) 'details': details!.trim(),
  };
}

class ReportReceipt {
  final bool submitted;
  final bool duplicate;
  const ReportReceipt({required this.submitted, required this.duplicate});
}

String newReportRequestId() {
  final random = Random.secure();
  final entropy = List.generate(
    4,
    (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
  ).join();
  return 'report_${DateTime.now().microsecondsSinceEpoch}_$entropy';
}
