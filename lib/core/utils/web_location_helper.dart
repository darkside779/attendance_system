// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class WebLocationHelper {
  /// Enable location testing mode for web browsers
  static bool _testingMode = false;
  static Position? _mockPosition;

  /// Enable testing mode with mock location
  static void enableTestingMode({
    double? latitude,
    double? longitude,
  }) {
    _testingMode = true;
    _mockPosition = Position(
      latitude: latitude ?? 24.366285, // Default to company location
      longitude: longitude ?? 54.499738,
      timestamp: DateTime.now(),
      accuracy: 10.0, // Good accuracy simulation
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    print('Web testing mode enabled at: $latitude, $longitude');
  }

  /// Disable testing mode
  static void disableTestingMode() {
    _testingMode = false;
    _mockPosition = null;
    print('Web testing mode disabled');
  }

  /// Get position for testing (if enabled) or real position
  static Future<Position?> getPosition() async {
    if (kIsWeb && _testingMode && _mockPosition != null) {
      print('Returning mock position for testing: ${_mockPosition!.latitude}, ${_mockPosition!.longitude}');
      return _mockPosition;
    }

    // Return real position
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      );
    } catch (e) {
      print('Real location failed: $e');
      return null;
    }
  }

  /// Check if currently in testing mode
  static bool get isTestingMode => _testingMode;

  /// Get mock position
  static Position? get mockPosition => _mockPosition;

  /// Simulate movement (for testing)
  static void simulateMovement(double latOffset, double lngOffset) {
    if (_testingMode && _mockPosition != null) {
      _mockPosition = Position(
        latitude: _mockPosition!.latitude + latOffset,
        longitude: _mockPosition!.longitude + lngOffset,
        timestamp: DateTime.now(),
        accuracy: _mockPosition!.accuracy,
        altitude: _mockPosition!.altitude,
        heading: _mockPosition!.heading,
        speed: _mockPosition!.speed,
        speedAccuracy: _mockPosition!.speedAccuracy,
        altitudeAccuracy: _mockPosition!.altitudeAccuracy,
        headingAccuracy: _mockPosition!.headingAccuracy,
      );
      print('Simulated movement to: ${_mockPosition!.latitude}, ${_mockPosition!.longitude}');
    }
  }
}
