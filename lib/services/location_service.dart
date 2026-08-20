import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    return true;
  }

  // Check and request location permissions
  Future<LocationPermission> checkAndRequestPermission() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }
    
    return permission;
  }

  /// How long to wait for a fix before giving up.
  ///
  /// Without a bound this can wait forever — a browser permission prompt nobody
  /// answers, or a device indoors with no signal — and every caller that awaits
  /// it hangs with it.
  static const Duration fixTimeout = Duration(seconds: 12);

  /// Resolves the device's position, or gives up.
  ///
  /// The timeout wraps the permission request as well as the fix. A browser
  /// permission prompt nobody answers never returns, so bounding only the fix
  /// leaves the caller hanging at the step before it.
  Future<Position> getCurrentPosition() async {
    try {
      return await _resolvePosition().timeout(fixTimeout);
    } catch (e) {
      debugPrint('Error getting current position: $e');
      rethrow;
    }
  }

  Future<Position> _resolvePosition() async {
    await checkAndRequestPermission();
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: fixTimeout,
    );
  }

  // Get address from coordinates
  Future<String?> getAddressFromLatLng(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
      }
      return null;
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');
      return null;
    }
  }

  // Calculate distance between two coordinates in kilometers
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    ) / 1000; // Convert to kilometers
  }

  // Get current location with address
  Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      final position = await getCurrentPosition();
      final address = await getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
      };
    } catch (e) {
      debugPrint('Error getting current location: $e');
      rethrow;
    }
  }
}
