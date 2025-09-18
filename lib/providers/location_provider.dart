// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/settings_model.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  
  Position? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;
  LocationPermission _permissionStatus = LocationPermission.denied;
  bool _isLocationServiceEnabled = false;
  LocationModel? _companyLocation;
  LocationCheckResult? _lastLocationCheck;
  
  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  LocationPermission get permissionStatus => _permissionStatus;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;
  LocationModel? get companyLocation => _companyLocation;
  LocationCheckResult? get lastLocationCheck => _lastLocationCheck;
  
  // Status getters
  bool get hasLocationPermission => 
      _permissionStatus == LocationPermission.always ||
      _permissionStatus == LocationPermission.whileInUse;
  
  bool get canUseLocation => hasLocationPermission && _isLocationServiceEnabled;
  
  bool get isWithinCompanyLocation => _lastLocationCheck?.isWithinRange ?? false;

  /// Initialize location services
  Future<void> initialize(LocationModel companyLocation) async {
    _companyLocation = companyLocation;
    await checkLocationStatus();
  }

  /// Check location permission and service status
  Future<void> checkLocationStatus() async {
    _setLoading(true);
    _clearError();

    try {
      // Check if location services are enabled
      _isLocationServiceEnabled = await _locationService.isLocationServiceEnabled();
      
      // Check permission status
      _permissionStatus = await _locationService.checkLocationPermission();
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to check location status: $e');
    }
    
    _setLoading(false);
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    _setLoading(true);
    _clearError();

    try {
      _permissionStatus = await _locationService.requestLocationPermission();
      _setLoading(false);
      return hasLocationPermission;
    } catch (e) {
      _setError('Failed to request location permission: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Get current location
  Future<bool> getCurrentLocation() async {
    _setLoading(true);
    _clearError();

    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _currentPosition = position;
        
        // If company location is set, check if user is within range
        if (_companyLocation != null) {
          await checkCompanyLocation();
        }
        
        _setLoading(false);
        return true;
      } else {
        _setError('Failed to get current location');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Error getting location: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Check if user is within company location
  Future<bool> checkCompanyLocation() async {
    if (_companyLocation == null) {
      _setError('Company location not set');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await _locationService.checkUserLocation(_companyLocation!);
      _lastLocationCheck = result;
      _setLoading(false);
      return result.isWithinRange;
    } catch (e) {
      _setError('Error checking company location: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Validate location for attendance
  Future<AttendanceLocationResult> validateLocationForAttendance() async {
    if (_companyLocation == null) {
      return AttendanceLocationResult(
        isValid: false,
        message: 'Company location not configured',
      );
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await _locationService.validateLocationForAttendance(_companyLocation!);
      
      if (result.isValid) {
        _currentPosition = Position(
          latitude: result.currentLatitude!,
          longitude: result.currentLongitude!,
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
      
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('Error validating location: $e');
      _setLoading(false);
      return AttendanceLocationResult(
        isValid: false,
        message: 'Error validating location: $e',
      );
    }
  }

  /// Get distance from company location
  double? get distanceFromCompany {
    return _lastLocationCheck?.distance;
  }

  /// Get formatted distance from company location
  String get formattedDistanceFromCompany {
    final distance = distanceFromCompany;
    if (distance == null) return 'Unknown';
    
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Get address from current location
  Future<String?> getCurrentAddress() async {
    if (_currentPosition == null) return null;

    try {
      return await _locationService.getAddressFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  /// Start location tracking
  void startLocationTracking() {
    _locationService.getLocationStream().listen(
      (Position position) {
        _currentPosition = position;
        
        // Check company location if set
        if (_companyLocation != null) {
          checkCompanyLocation();
        }
        
        notifyListeners();
      },
      onError: (error) {
        _setError('Location tracking error: $error');
      },
    );
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    try {
      return await _locationService.openLocationSettings();
    } catch (e) {
      _setError('Failed to open location settings: $e');
      return false;
    }
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    try {
      return await _locationService.openAppSettings();
    } catch (e) {
      _setError('Failed to open app settings: $e');
      return false;
    }
  }

  /// Set company location
  void setCompanyLocation(LocationModel location) {
    _companyLocation = location;
    notifyListeners();
  }

  /// Clear current location
  void clearLocation() {
    _currentPosition = null;
    _lastLocationCheck = null;
    notifyListeners();
  }

  /// Refresh location data
  Future<void> refresh() async {
    await checkLocationStatus();
    if (canUseLocation) {
      await getCurrentLocation();
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error manually
  void clearError() {
    _clearError();
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }
}
