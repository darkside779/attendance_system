// ignore_for_file: avoid_print

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/utils/location_checker.dart';
import '../models/settings_model.dart';

class LocationService {
  /// Get current user location
  Future<Position?> getCurrentLocation() async {
    return await LocationChecker.getCurrentPosition();
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await LocationChecker.isLocationServiceEnabled();
  }

  /// Check location permission
  Future<LocationPermission> checkLocationPermission() async {
    return await LocationChecker.checkLocationPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    return await LocationChecker.requestLocationPermission();
  }

  /// Check if user is within company location
  Future<LocationCheckResult> checkUserLocation(LocationModel companyLocation) async {
    try {
      // Get current position
      final currentPosition = await getCurrentLocation();
      if (currentPosition == null) {
        return LocationCheckResult(
          isWithinRange: false,
          message: 'Unable to get current location',
          distance: null,
        );
      }

      // Calculate distance from company location
      final distance = LocationChecker.calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        companyLocation.latitude,
        companyLocation.longitude,
      );

      // Check if within allowed radius
      final isWithinRange = distance <= companyLocation.radiusMeters;

      return LocationCheckResult(
        isWithinRange: isWithinRange,
        message: isWithinRange 
            ? 'You are within the work area'
            : 'You are ${LocationChecker.formatDistance(distance)} away from work area',
        distance: distance,
        currentLatitude: currentPosition.latitude,
        currentLongitude: currentPosition.longitude,
      );
    } catch (e) {
      return LocationCheckResult(
        isWithinRange: false,
        message: 'Error checking location: $e',
        distance: null,
      );
    }
  }

  /// Get address from coordinates
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        // Build address string with null checks
        List<String> addressParts = [];
        
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressParts.add(placemark.street!);
        }
        if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
          addressParts.add(placemark.subLocality!);
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressParts.add(placemark.locality!);
        }
        if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
          addressParts.add(placemark.administrativeArea!);
        }
        if (placemark.country != null && placemark.country!.isNotEmpty) {
          addressParts.add(placemark.country!);
        }
        
        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        } else {
          return 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
        }
      }
      return 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
    } catch (e) {
      // Return coordinates as fallback instead of error message
      return 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
    }
  }

  /// Get coordinates from address
  Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Start location tracking
  Stream<Position> getLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );
    
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Check if user moved significantly
  bool hasUserMoved(Position oldPosition, Position newPosition, {double threshold = 50.0}) {
    final distance = LocationChecker.calculateDistance(
      oldPosition.latitude,
      oldPosition.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );
    return distance >= threshold;
  }

  /// Validate location for attendance
  Future<AttendanceLocationResult> validateLocationForAttendance(
    LocationModel companyLocation,
  ) async {
    try {
      // Check location permission
      final permission = await checkLocationPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        return AttendanceLocationResult(
          isValid: false,
          message: 'Location permission denied. Please enable location access.',
          requiresPermission: true,
        );
      }

      // Check if location services are enabled
      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        return AttendanceLocationResult(
          isValid: false,
          message: 'Location services are disabled. Please enable location services.',
          requiresLocationService: true,
        );
      }

      // Check user location
      final locationResult = await checkUserLocation(companyLocation);
      
      return AttendanceLocationResult(
        isValid: locationResult.isWithinRange,
        message: locationResult.message,
        distance: locationResult.distance,
        currentLatitude: locationResult.currentLatitude,
        currentLongitude: locationResult.currentLongitude,
      );
    } catch (e) {
      return AttendanceLocationResult(
        isValid: false,
        message: 'Error validating location: $e',
      );
    }
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      return false;
    }
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      return false;
    }
  }
}

class LocationCheckResult {
  final bool isWithinRange;
  final String message;
  final double? distance;
  final double? currentLatitude;
  final double? currentLongitude;

  LocationCheckResult({
    required this.isWithinRange,
    required this.message,
    this.distance,
    this.currentLatitude,
    this.currentLongitude,
  });
}

class AttendanceLocationResult {
  final bool isValid;
  final String message;
  final double? distance;
  final double? currentLatitude;
  final double? currentLongitude;
  final bool requiresPermission;
  final bool requiresLocationService;

  AttendanceLocationResult({
    required this.isValid,
    required this.message,
    this.distance,
    this.currentLatitude,
    this.currentLongitude,
    this.requiresPermission = false,
    this.requiresLocationService = false,
  });
}
