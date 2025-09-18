class LocationConstants {
  // Default company location (update with actual coordinates)
  static const double defaultLatitude = 37.7749;
  static const double defaultLongitude = -122.4194;
  static const double defaultRadius = 100.0; // meters

  // Location accuracy settings
  static const double locationAccuracy = 10.0; // meters
  static const int locationTimeout = 30; // seconds

  // Geofencing settings
  static const double geofenceRadius = 100.0; // meters
  static const String geofenceId = 'company_location';

  // Location permission messages
  static const String locationPermissionTitle = 'Location Permission Required';
  static const String locationPermissionMessage = 
      'This app needs location access to verify you are at the workplace for attendance tracking.';
  
  static const String locationServiceDisabledTitle = 'Location Services Disabled';
  static const String locationServiceDisabledMessage = 
      'Please enable location services to use attendance features.';
}
