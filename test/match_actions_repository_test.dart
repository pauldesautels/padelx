import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/match_actions_repository.dart';

void main() {
  test(
    'leaveMatch invokes only the narrow callable with authenticated actor payload',
    () async {
      String? calledName;
      Map<String, Object?>? calledPayload;
      var calls = 0;
      final repository = FirebaseMatchActionsRepository(
        callable: (name, payload) async {
          calls += 1;
          calledName = name;
          calledPayload = payload;
        },
      );

      await repository.leaveMatch('match-123', 'leave_request_12345678');

      expect(calls, 1);
      expect(calledName, 'leaveMatch');
      expect(calledPayload, {
        'matchId': 'match-123',
        'requestId': 'leave_request_12345678',
      });
      expect(calledPayload, isNot(contains('participantUid')));
    },
  );
}
