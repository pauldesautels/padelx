import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchmakingMode { solo, partner, autofill }

enum MatchmakingVenueType { clubPublic, privateFree }

extension MatchmakingVenueTypeValue on MatchmakingVenueType {
  String get storageValue => switch (this) {
    MatchmakingVenueType.clubPublic => 'club_public',
    MatchmakingVenueType.privateFree => 'private_free',
  };
}

class MatchmakingVenueInput {
  final MatchmakingVenueType type;
  final String label;
  final String? placeId;
  final String? address;
  final double latitude;
  final double longitude;
  final String countryCode;
  final String country;
  final String cityId;
  final String city;
  final String areaId;
  final String area;

  const MatchmakingVenueInput({
    required this.type,
    required this.label,
    this.placeId,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.countryCode,
    required this.country,
    required this.cityId,
    required this.city,
    this.areaId = '',
    this.area = '',
  });

  Map<String, Object> toPayload() => {
    'type': type.storageValue,
    'label': label,
    'placeId': ?placeId,
    'address': ?address,
    'latitude': latitude,
    'longitude': longitude,
    'country': country,
    'countryCode': countryCode,
    'cityId': cityId,
    'city': city,
    'areaId': areaId,
    'area': area,
  };
}

extension MatchmakingModeValue on MatchmakingMode {
  String get storageValue => switch (this) {
    MatchmakingMode.solo => 'solo',
    MatchmakingMode.partner => 'partner',
    MatchmakingMode.autofill => 'autofill',
  };
}

class MatchmakingAvailability {
  final DateTime earliestStart;
  final DateTime latestStart;

  const MatchmakingAvailability({
    required this.earliestStart,
    required this.latestStart,
  });

  Map<String, Object> toPayload() => {
    'earliestStart': earliestStart.toUtc().toIso8601String(),
    'latestStart': latestStart.toUtc().toIso8601String(),
  };
}

class MatchmakingRequestInput {
  final String requestId;
  final MatchmakingMode mode;
  final List<MatchmakingAvailability> availability;
  final String timezone;
  final int travelRadiusKm;
  final String preferredSide;
  final String? partnerUid;
  final String? sourceMatchId;
  final bool autoFillAfterCancellation;

  const MatchmakingRequestInput({
    required this.requestId,
    required this.mode,
    required this.availability,
    required this.timezone,
    required this.travelRadiusKm,
    required this.preferredSide,
    this.partnerUid,
    this.sourceMatchId,
    this.autoFillAfterCancellation = false,
  });

  Map<String, Object> toPayload() => {
    'requestId': requestId,
    'mode': mode.storageValue,
    'availability': availability.map((window) => window.toPayload()).toList(),
    'timezone': timezone,
    'travelRadiusKm': travelRadiusKm,
    'preferredSide': preferredSide,
    'partnerUid': ?partnerUid,
    'sourceMatchId': ?sourceMatchId,
    if (mode == MatchmakingMode.autofill)
      'autoFillAfterCancellation': autoFillAfterCancellation,
  };
}

class MatchmakingState {
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> proposals;

  const MatchmakingState({required this.requests, required this.proposals});
}

abstract class MatchmakingRepository {
  Future<Map<String, dynamic>> create(MatchmakingRequestInput input);
  Future<void> respondToPartner(String requestId, {required bool accept});
  Future<void> cancel(String requestId);
  Future<void> respondToProposal(
    String proposalId, {
    required bool accept,
    required String requestId,
  });
  Future<MatchmakingState> state();
  Future<String> resolveVenue(
    String proposalId,
    String requestId,
    MatchmakingVenueInput venue,
  );
  Stream<void> watchStateInvalidations(String uid);
}

class FirebaseMatchmakingRepository implements MatchmakingRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  FirebaseMatchmakingRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> payload,
  ) async {
    final result = await _functions.httpsCallable(name).call(payload);
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<Map<String, dynamic>> create(MatchmakingRequestInput input) =>
      _call('createMatchmakingRequest', input.toPayload());

  @override
  Future<void> respondToPartner(
    String requestId, {
    required bool accept,
  }) async {
    await _call('respondPartnerInvitation', {
      'requestId': requestId,
      'accept': accept,
    });
  }

  @override
  Future<void> cancel(String requestId) async {
    await _call('cancelMatchmakingRequest', {'requestId': requestId});
  }

  @override
  Future<void> respondToProposal(
    String proposalId, {
    required bool accept,
    required String requestId,
  }) async {
    await _call('respondMatchProposal', {
      'proposalId': proposalId,
      'accept': accept,
      'requestId': requestId,
    });
  }

  @override
  Future<MatchmakingState> state() async {
    final result = await _call('getMatchmakingState', const {});
    return MatchmakingState(
      requests: (result['requests'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      proposals: (result['proposals'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }

  @override
  Future<String> resolveVenue(
    String proposalId,
    String requestId,
    MatchmakingVenueInput venue,
  ) async {
    final result = await _call('resolveMatchmakingVenue', {
      'proposalId': proposalId,
      'requestId': requestId,
      'venue': venue.toPayload(),
    });
    return result['matchId'] as String;
  }

  @override
  Stream<void> watchStateInvalidations(String uid) {
    final requests = _firestore
        .collection('users')
        .doc(uid)
        .collection('matchmakingRequestViews')
        .snapshots()
        .map((_) {});
    final proposals = _firestore
        .collection('users')
        .doc(uid)
        .collection('matchProposalViews')
        .snapshots()
        .map((_) {});
    return Stream<void>.multi((controller) {
      final subscriptions = <StreamSubscription<void>>[
        requests.listen(controller.add, onError: controller.addError),
        proposals.listen(controller.add, onError: controller.addError),
      ];
      controller.onCancel = () async {
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
      };
    });
  }
}
