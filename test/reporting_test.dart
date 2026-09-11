import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/conversation_screen.dart';
import 'package:padelx/messaging.dart';
import 'package:padelx/report_flow.dart';
import 'package:padelx/report_repository.dart';
import 'package:padelx/reporting.dart';

class _Reports implements ReportRepository {
  final List<ReportRequest> requests = [];
  final List<Object> outcomes;
  _Reports([this.outcomes = const []]);

  @override
  Future<ReportReceipt> submit(ReportRequest request) async {
    requests.add(request);
    final outcome = outcomes.length >= requests.length
        ? outcomes[requests.length - 1]
        : const ReportReceipt(submitted: true, duplicate: false);
    if (outcome is Exception) throw outcome;
    if (outcome is Future<ReportReceipt>) return outcome;
    return outcome as ReportReceipt;
  }
}

Widget _dialog(
  _Reports repository, {
  String requestId = 'report_request_123456',
}) => MaterialApp(
  home: Scaffold(
    body: ReportDialog(
      repository: repository,
      requestId: requestId,
      subjectType: ReportSubjectType.player,
      subjectId: 'target',
    ),
  ),
);

Future<void> _selectReason(WidgetTester tester, String value) async {
  final finder = find.byKey(Key('report-reason-$value'));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  test(
    'canonical report model has exact subjects, reasons, and trimmed payload',
    () {
      expect(ReportSubjectType.values.map((value) => value.name), [
        'player',
        'message',
        'match',
      ]);
      expect(ReportReason.values.map((value) => value.value), [
        'harassment_bullying',
        'hate_abuse',
        'sexual_inappropriate',
        'threats_unsafe_behavior',
        'spam_scam',
        'impersonation',
        'other',
      ]);
      expect(
        const ReportRequest(
          requestId: 'report_request_123456',
          subjectType: ReportSubjectType.player,
          subjectId: 'target',
          reason: ReportReason.other,
          details: '  context  ',
        ).toMap()['details'],
        'context',
      );
      expect(
        const ReportRequest(
          requestId: 'report_request_123456',
          subjectType: ReportSubjectType.message,
          subjectId: 'message-id',
          conversationId: 'conversation-id',
          reason: ReportReason.harassmentBullying,
        ).toMap(),
        containsPair('conversationId', 'conversation-id'),
      );
    },
  );

  testWidgets('report form selects reason, limits details, and submits once', (
    tester,
  ) async {
    final repository = _Reports();
    await tester.pumpWidget(_dialog(repository));

    expect(find.byKey(const Key('submit-report')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submit-report')))
          .onPressed,
      isNull,
    );
    expect(
      ReportReason.values.every(
        (reason) => find
            .byKey(Key('report-reason-${reason.value}'))
            .evaluate()
            .isNotEmpty,
      ),
      true,
    );

    await _selectReason(tester, 'other');
    final longDetails = List.filled(reportDetailsLimit, 'x').join();
    await tester.enterText(
      find.byKey(const Key('report-details')),
      longDetails,
    );
    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pumpAndSettle();

    expect(repository.requests, hasLength(1));
    expect(repository.requests.single.details, longDetails);
    expect(repository.requests.single.reason, ReportReason.other);
  });

  testWidgets('failure preserves form and retry reuses the same request ID', (
    tester,
  ) async {
    final repository = _Reports([
      const ReportFailure(ReportFailureKind.generic),
      const ReportReceipt(submitted: true, duplicate: true),
    ]);
    await tester.pumpWidget(_dialog(repository));
    await _selectReason(tester, 'spam_scam');
    await tester.enterText(
      find.byKey(const Key('report-details')),
      ' evidence ',
    );
    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pump();

    expect(
      find.text('Report could not be submitted. Please try again.'),
      findsOneWidget,
    );
    expect(find.text(' evidence '), findsOneWidget);
    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pumpAndSettle();

    expect(repository.requests, hasLength(2));
    expect(repository.requests[0].requestId, repository.requests[1].requestId);
    expect(repository.requests[1].details, ' evidence ');
  });

  testWidgets('loading prevents duplicate taps', (tester) async {
    final completion = Completer<ReportReceipt>();
    final repository = _Reports([completion.future]);
    await tester.pumpWidget(_dialog(repository));
    await _selectReason(tester, 'other');
    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pump();
    expect(repository.requests, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completion.complete(const ReportReceipt(submitted: true, duplicate: false));
    await tester.pumpAndSettle();
  });

  testWidgets('Cancel dismisses without submission', (tester) async {
    final cancelled = _Reports();
    await tester.pumpWidget(_dialog(cancelled));
    await tester.tap(find.byKey(const Key('cancel-report')));
    await tester.pumpAndSettle();
    expect(cancelled.requests, isEmpty);
  });

  testWidgets('safe duplicate and rate limit copy do not expose thresholds', (
    tester,
  ) async {
    for (final entry in [
      (ReportFailureKind.alreadyReported, 'You already reported this.'),
      (
        ReportFailureKind.rateLimited,
        'You’ve submitted several reports recently. Please try again later.',
      ),
    ]) {
      final repository = _Reports([ReportFailure(entry.$1)]);
      await tester.pumpWidget(_dialog(repository));
      await _selectReason(tester, 'other');
      await tester.tap(find.byKey(const Key('submit-report')));
      await tester.pump();
      expect(find.text(entry.$2), findsOneWidget);
    }
  });

  testWidgets(
    'remote bubble offers long-press and accessibility report action',
    (tester) async {
      var reports = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: const ChatMessage(
                id: 'message',
                senderUid: 'other',
                text: 'Remote message',
              ),
              mine: false,
              identity: const MessagingIdentity(
                uid: 'other',
                displayName: 'Other',
              ),
              showIdentity: true,
              showSenderName: false,
              showTimestamp: false,
              grouped: false,
              onReport: () => reports++,
            ),
          ),
        ),
      );
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(MessageBubble)).toStringDeep(),
        contains('Report message'),
      );
      await tester.longPress(find.text('Remote message'));
      await tester.pumpAndSettle();
      expect(find.text('Report message'), findsOneWidget);
      await tester.tap(find.byKey(const Key('report-message-action')));
      await tester.pumpAndSettle();
      expect(reports, 1);
      handle.dispose();
    },
  );

  testWidgets('own bubble exposes no report interaction', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage(id: 'mine', senderUid: 'me', text: 'Mine'),
            mine: true,
            identity: MessagingIdentity(uid: 'me', displayName: 'Me'),
            showIdentity: false,
            showSenderName: false,
            showTimestamp: false,
            grouped: false,
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Mine'));
    await tester.pumpAndSettle();
    expect(find.text('Report message'), findsNothing);
  });

  testWidgets('block failure after report remains block-specific', (
    tester,
  ) async {
    final repository = _Reports();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showReportFlow(
                context: context,
                repository: repository,
                subjectType: ReportSubjectType.player,
                subjectId: 'target',
                onBlockPlayer: () => throw StateError('synthetic'),
              ),
              child: const Text('Begin'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    await _selectReason(tester, 'other');
    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pumpAndSettle();
    expect(find.text('Report submitted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('report-success-block')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-report-block')));
    await tester.pumpAndSettle();
    expect(find.text('Player could not be blocked.'), findsOneWidget);
    expect(repository.requests, hasLength(1));
  });
}
