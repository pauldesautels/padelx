import 'package:cloud_functions/cloud_functions.dart';

typedef MatchActionCallable =
    Future<void> Function(String name, Map<String, Object?> payload);

abstract class MatchActionsRepository {
  Future<void> leaveMatch(String matchId, String requestId);
}

class FirebaseMatchActionsRepository implements MatchActionsRepository {
  final FirebaseFunctions? _functions;
  final MatchActionCallable? _callable;

  FirebaseMatchActionsRepository({
    FirebaseFunctions? functions,
    MatchActionCallable? callable,
  }) : _functions = functions,
       _callable = callable;

  @override
  Future<void> leaveMatch(String matchId, String requestId) async {
    final payload = <String, Object?>{
      'matchId': matchId,
      'requestId': requestId,
    };
    if (_callable != null) {
      await _callable('leaveMatch', payload);
      return;
    }
    await (_functions ?? FirebaseFunctions.instance)
        .httpsCallable('leaveMatch')
        .call(payload);
  }
}
