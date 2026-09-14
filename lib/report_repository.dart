import 'package:cloud_functions/cloud_functions.dart';

import 'reporting.dart';
import 'account_access.dart';

enum ReportFailureKind { alreadyReported, rateLimited, generic }

class ReportFailure implements Exception {
  final ReportFailureKind kind;
  const ReportFailure(this.kind);
}

abstract class ReportRepository {
  Future<ReportReceipt> submit(ReportRequest request);
}

class FirebaseReportRepository implements ReportRepository {
  final FirebaseFunctions functions;
  FirebaseReportRepository({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<ReportReceipt> submit(ReportRequest request) async {
    try {
      final response = await functions
          .httpsCallable('submitReport')
          .call(request.toMap());
      final data = Map<dynamic, dynamic>.from(response.data as Map);
      return ReportReceipt(
        submitted: data['submitted'] == true,
        duplicate: data['duplicate'] == true,
      );
    } on FirebaseFunctionsException catch (error) {
      signalAccountAccessRestriction(error);
      throw ReportFailure(switch (error.code) {
        'already-exists' => ReportFailureKind.alreadyReported,
        'resource-exhausted' => ReportFailureKind.rateLimited,
        _ => ReportFailureKind.generic,
      });
    } catch (_) {
      throw const ReportFailure(ReportFailureKind.generic);
    }
  }
}
