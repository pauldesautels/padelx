import 'package:cloud_functions/cloud_functions.dart';
import 'account_access.dart';

Future<Set<String>> loadOwnRatingReceiptUids(
  String matchId,
  List<String> ratedUids, {
  FirebaseFunctions? functions,
}) async {
  if (matchId.isEmpty || ratedUids.isEmpty) return {};
  try {
    final result = await (functions ?? FirebaseFunctions.instance)
        .httpsCallable('getOwnRatingReceipts')
        .call({'matchId': matchId, 'ratedUids': ratedUids});
    final values = result.data is Map
        ? result.data['submittedRatedUids']
        : null;
    if (values is! List ||
        values.any((value) => value is! String || !ratedUids.contains(value))) {
      throw const FormatException('Invalid rating receipt response.');
    }
    return values.cast<String>().toSet();
  } catch (error) {
    signalAccountAccessRestriction(error);
    rethrow;
  }
}
