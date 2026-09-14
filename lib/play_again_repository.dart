import 'package:cloud_functions/cloud_functions.dart';
import 'account_access.dart';

abstract class PlayAgainRepository {
  Future<void> invite({
    required String matchId,
    required String inviteeUid,
    String? sourceMatchId,
  });
  Future<void> dismiss(String matchId);
}

class FirebasePlayAgainRepository implements PlayAgainRepository {
  final FirebaseFunctions functions;
  FirebasePlayAgainRepository({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<void> invite({
    required String matchId,
    required String inviteeUid,
    String? sourceMatchId,
  }) async {
    try {
      await functions.httpsCallable('createPlayAgainInvitation').call({
        'matchId': matchId,
        'inviteeUid': inviteeUid,
        if (sourceMatchId != null && sourceMatchId.isNotEmpty)
          'sourceMatchId': sourceMatchId,
      });
    } catch (error) {
      signalAccountAccessRestriction(error);
      rethrow;
    }
  }

  @override
  Future<void> dismiss(String matchId) async {
    try {
      await functions.httpsCallable('dismissPlayAgainInvitation').call({
        'matchId': matchId,
      });
    } catch (error) {
      signalAccountAccessRestriction(error);
      rethrow;
    }
  }
}
