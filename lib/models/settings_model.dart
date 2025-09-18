import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsModel {
  final String companyId;
  final String companyName;
  final LocationModel allowedLocation;
  final List<ShiftModel> shifts;
  final DateTime updatedAt;

  SettingsModel({
    required this.companyId,
    required this.companyName,
    required this.allowedLocation,
    required this.shifts,
    required this.updatedAt,
  });

  // Convert SettingsModel to Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'allowedLocation': allowedLocation.toJson(),
      'shifts': shifts.map((shift) => shift.toJson()).toList(),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create SettingsModel from Firestore document
  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      companyId: json['companyId'] ?? '',
      companyName: json['companyName'] ?? '',
      allowedLocation: LocationModel.fromJson(json['allowedLocation'] ?? {}),
      shifts: (json['shifts'] as List<dynamic>?)
              ?.map((shift) => ShiftModel.fromJson(shift))
              .toList() ??
          [],
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create SettingsModel from Firestore DocumentSnapshot
  factory SettingsModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }
    return SettingsModel.fromJson({...data, 'companyId': doc.id});
  }

  // Copy with method for updating settings
  SettingsModel copyWith({
    String? companyId,
    String? companyName,
    LocationModel? allowedLocation,
    List<ShiftModel>? shifts,
    DateTime? updatedAt,
  }) {
    return SettingsModel(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      allowedLocation: allowedLocation ?? this.allowedLocation,
      shifts: shifts ?? this.shifts,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LocationModel {
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String address;

  LocationModel({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.address,
  });

  // Convert LocationModel to Map
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'address': address,
    };
  }

  // Create LocationModel from Map
  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      radiusMeters: json['radiusMeters']?.toDouble() ?? 100.0,
      address: json['address'] ?? '',
    );
  }

  // Copy with method
  LocationModel copyWith({
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? address,
  }) {
    return LocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      address: address ?? this.address,
    );
  }
}

class ShiftModel {
  final String shiftId;
  final String shiftName;
  final String startTime; // Format: "HH:mm"
  final String endTime; // Format: "HH:mm"
  final List<String> workingDays; // ["monday", "tuesday", etc.]
  final int gracePeriodMinutes;
  final bool isActive;

  ShiftModel({
    required this.shiftId,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.workingDays,
    this.gracePeriodMinutes = 15,
    this.isActive = true,
  });

  // Convert ShiftModel to Map
  Map<String, dynamic> toJson() {
    return {
      'shiftId': shiftId,
      'shiftName': shiftName,
      'startTime': startTime,
      'endTime': endTime,
      'workingDays': workingDays,
      'gracePeriodMinutes': gracePeriodMinutes,
      'isActive': isActive,
    };
  }

  // Create ShiftModel from Map
  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      shiftId: json['shiftId'] ?? '',
      shiftName: json['shiftName'] ?? '',
      startTime: json['startTime'] ?? '09:00',
      endTime: json['endTime'] ?? '17:00',
      workingDays: List<String>.from(json['workingDays'] ?? []),
      gracePeriodMinutes: json['gracePeriodMinutes'] ?? 15,
      isActive: json['isActive'] ?? true,
    );
  }

  // Copy with method
  ShiftModel copyWith({
    String? shiftId,
    String? shiftName,
    String? startTime,
    String? endTime,
    List<String>? workingDays,
    int? gracePeriodMinutes,
    bool? isActive,
  }) {
    return ShiftModel(
      shiftId: shiftId ?? this.shiftId,
      shiftName: shiftName ?? this.shiftName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      workingDays: workingDays ?? this.workingDays,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      isActive: isActive ?? this.isActive,
    );
  }

  // Get shift duration in minutes
  int get durationMinutes {
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    
    if (end.isBefore(start)) {
      // Handle overnight shifts
      final nextDay = end.add(const Duration(days: 1));
      return nextDay.difference(start).inMinutes;
    }
    
    return end.difference(start).inMinutes;
  }

  // Parse time string to DateTime (today's date with specified time)
  DateTime _parseTime(String timeString) {
    final parts = timeString.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  // Get expected check-in time for today
  DateTime getExpectedCheckInTime() {
    return _parseTime(startTime);
  }

  // Get expected check-out time for today
  DateTime getExpectedCheckOutTime() {
    return _parseTime(endTime);
  }

  // Check if today is a working day
  bool get isTodayWorkingDay {
    final today = DateTime.now().weekday;
    final dayName = _getDayName(today).toLowerCase();
    return workingDays.contains(dayName);
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'monday';
      case 2:
        return 'tuesday';
      case 3:
        return 'wednesday';
      case 4:
        return 'thursday';
      case 5:
        return 'friday';
      case 6:
        return 'saturday';
      case 7:
        return 'sunday';
      default:
        return 'monday';
    }
  }
}
