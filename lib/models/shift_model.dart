class ShiftModel {
  final String shiftId;
  final String shiftName;
  final String startTime; // Format: "HH:mm"
  final String endTime;   // Format: "HH:mm"
  final List<String> workingDays;
  final int gracePeriodMinutes;
  final bool isActive;
  final DateTime? updatedAt;

  ShiftModel({
    required this.shiftId,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.workingDays,
    this.gracePeriodMinutes = 15,
    this.isActive = true,
    this.updatedAt,
  });

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      shiftId: map['shiftId'] ?? '',
      shiftName: map['shiftName'] ?? '',
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'] ?? '17:00',
      workingDays: List<String>.from(map['workingDays'] ?? []),
      gracePeriodMinutes: map['gracePeriodMinutes'] ?? 15,
      isActive: map['isActive'] ?? true,
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shiftId': shiftId,
      'shiftName': shiftName,
      'startTime': startTime,
      'endTime': endTime,
      'workingDays': workingDays,
      'gracePeriodMinutes': gracePeriodMinutes,
      'isActive': isActive,
      'updatedAt': updatedAt,
    };
  }

  // Parse time string to minutes since midnight
  int get startTimeMinutes {
    final parts = startTime.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return hours * 60 + minutes;
  }

  int get endTimeMinutes {
    final parts = endTime.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    // Handle 24:00 as midnight next day
    if (hours == 24) return 24 * 60;
    return hours * 60 + minutes;
  }

  // Check if current time is within shift window (including grace period)
  bool isWithinShiftWindow(DateTime dateTime) {
    if (!isActive) return false;
    
    final currentDay = _getDayName(dateTime.weekday);
    if (!workingDays.contains(currentDay.toLowerCase())) return false;
    
    final currentMinutes = dateTime.hour * 60 + dateTime.minute;
    final shiftStart = startTimeMinutes - gracePeriodMinutes; // 30 min early
    final shiftEnd = endTimeMinutes;
    
    // Handle overnight shifts (like 04:00-24:00)
    if (shiftEnd > shiftStart) {
      return currentMinutes >= shiftStart && currentMinutes <= shiftEnd;
    } else {
      // Overnight shift
      return currentMinutes >= shiftStart || currentMinutes <= shiftEnd;
    }
  }

  // Check if user can check in (within grace period before shift start)
  bool canCheckIn(DateTime dateTime) {
    if (!isActive) return false;
    
    final currentDay = _getDayName(dateTime.weekday);
    if (!workingDays.contains(currentDay.toLowerCase())) return false;
    
    final currentMinutes = dateTime.hour * 60 + dateTime.minute;
    final checkInStart = startTimeMinutes - gracePeriodMinutes;
    final checkInEnd = endTimeMinutes;
    
    if (checkInEnd > checkInStart) {
      return currentMinutes >= checkInStart && currentMinutes <= checkInEnd;
    } else {
      // Overnight shift
      return currentMinutes >= checkInStart || currentMinutes <= checkInEnd;
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }

  // Get formatted time display
  String get formattedShiftTime {
    return '$startTime - $endTime';
  }

  // Check if user is late based on grace period
  bool isLateCheckIn(DateTime checkInTime) {
    final checkInMinutes = checkInTime.hour * 60 + checkInTime.minute;
    final lateThreshold = startTimeMinutes + gracePeriodMinutes;
    return checkInMinutes > lateThreshold;
  }

  @override
  String toString() {
    return 'ShiftModel(shiftId: $shiftId, shiftName: $shiftName, time: $formattedShiftTime, active: $isActive)';
  }
}
