import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum CurrentLocationError {
  permissionDenied,
  permissionPermanentlyDenied,
  servicesDisabled,
  timedOut,
  unavailable,
}

class CurrentLocationException implements Exception {
  final CurrentLocationError error;

  const CurrentLocationException(this.error);

  String get userMessage => switch (error) {
    CurrentLocationError.permissionDenied =>
      'Location permission was denied. You can still search for a location manually.',
    CurrentLocationError.permissionPermanentlyDenied =>
      'Location permission is blocked. Enable it in your browser or device settings, or search manually.',
    CurrentLocationError.servicesDisabled =>
      'Location services are turned off or unavailable. Turn them on or search manually.',
    CurrentLocationError.timedOut =>
      'Finding your location took too long. Please try again or search manually.',
    CurrentLocationError.unavailable =>
      'We could not get your current location. Please try again or search manually.',
  };
}

class CurrentCoordinates {
  final double latitude;
  final double longitude;

  const CurrentCoordinates({required this.latitude, required this.longitude});
}

abstract interface class CurrentLocationProvider {
  Future<CurrentCoordinates> getCurrentLocation();
}

class GeolocatorCurrentLocationProvider implements CurrentLocationProvider {
  const GeolocatorCurrentLocationProvider();

  @override
  Future<CurrentCoordinates> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const CurrentLocationException(
          CurrentLocationError.servicesDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const CurrentLocationException(
          CurrentLocationError.permissionDenied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const CurrentLocationException(
          CurrentLocationError.permissionPermanentlyDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return CurrentCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on CurrentLocationException {
      rethrow;
    } on TimeoutException {
      throw const CurrentLocationException(CurrentLocationError.timedOut);
    } on LocationServiceDisabledException {
      throw const CurrentLocationException(
        CurrentLocationError.servicesDisabled,
      );
    } on PermissionDeniedException {
      throw const CurrentLocationException(
        CurrentLocationError.permissionDenied,
      );
    } catch (_) {
      throw const CurrentLocationException(CurrentLocationError.unavailable);
    }
  }
}
