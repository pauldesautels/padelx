import 'package:cloud_functions/cloud_functions.dart';

class AttendanceState {
  final bool eligible;
  final bool submitted;
  final bool resolved;
  const AttendanceState({required this.eligible, required this.submitted, required this.resolved});
}

abstract class AttendanceRepository {
  Future<AttendanceState> state(String matchId);
  Future<void> submit({required String matchId, required bool matchHappened,
    required List<String> attendedUids, required String requestId});
}

class FirebaseAttendanceRepository implements AttendanceRepository {
  final FirebaseFunctions functions;
  FirebaseAttendanceRepository({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<AttendanceState> state(String matchId) async {
    final result = await functions.httpsCallable('getAttendanceState').call({'matchId': matchId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return AttendanceState(eligible: data['eligible'] == true,
      submitted: data['submitted'] == true, resolved: data['resolved'] == true);
  }

  @override
  Future<void> submit({required String matchId, required bool matchHappened,
      required List<String> attendedUids, required String requestId}) async {
    await functions.httpsCallable('submitAttendanceEvidence').call({
      'matchId': matchId, 'matchHappened': matchHappened,
      'attendedUids': attendedUids, 'requestId': requestId,
    });
  }
}
