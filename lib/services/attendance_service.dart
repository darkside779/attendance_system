// ignore_for_file: avoid_print

import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../models/settings_model.dart';
import '../core/utils/time_calculator.dart';
import 'firestore_service.dart';
import 'location_service.dart';

class AttendanceService {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();

  /// Check in user
  Future<AttendanceResult> checkIn({
    required String userId,
    required LocationModel companyLocation,
    ShiftModel? userShift,
  }) async {
    try {
      // Validate location first
      final locationResult = await _locationService.validateLocationForAttendance(companyLocation);
      if (!locationResult.isValid) {
        return AttendanceResult(
          success: false,
          message: locationResult.message,
          requiresPermission: locationResult.requiresPermission,
          requiresLocationService: locationResult.requiresLocationService,
        );
      }

      // Check if user already checked in today
      final existingAttendance = await _firestoreService.getTodayAttendance(userId);
      if (existingAttendance != null && existingAttendance.hasCheckedIn) {
        return AttendanceResult(
          success: false,
          message: 'You have already checked in today',
          attendance: existingAttendance,
        );
      }

      final now = DateTime.now();
      final dateOnly = DateTime(now.year, now.month, now.day);
      
      // Determine attendance status
      String status = 'present';
      if (userShift != null) {
        final expectedCheckIn = userShift.getExpectedCheckInTime();
        final gracePeriod = Duration(minutes: userShift.gracePeriodMinutes);
        
        if (now.isAfter(expectedCheckIn.add(gracePeriod))) {
          status = 'late';
        }
      }

      // Create or update attendance record
      AttendanceModel attendance;
      if (existingAttendance != null) {
        // Update existing record
        attendance = existingAttendance.copyWith(
          checkInTime: now,
          status: status,
          checkInLatitude: locationResult.currentLatitude,
          checkInLongitude: locationResult.currentLongitude,
        );
      } else {
        // Create new record
        final attendanceId = '${userId}_${TimeCalculator.getCurrentDateString()}';
        attendance = AttendanceModel(
          attendanceId: attendanceId,
          userId: userId,
          date: dateOnly,
          checkInTime: now,
          status: status,
          checkInLatitude: locationResult.currentLatitude,
          checkInLongitude: locationResult.currentLongitude,
        );
      }

      // Save to database
      final success = existingAttendance != null 
          ? await _firestoreService.updateAttendance(attendance)
          : await _firestoreService.createAttendance(attendance);

      if (success) {
        return AttendanceResult(
          success: true,
          message: 'Check-in successful',
          attendance: attendance,
        );
      } else {
        return AttendanceResult(
          success: false,
          message: 'Failed to save check-in record',
        );
      }
    } catch (e) {
      print('Error during check-in: $e');
      return AttendanceResult(
        success: false,
        message: 'Error during check-in: $e',
      );
    }
  }

  /// Check out user
  Future<AttendanceResult> checkOut({
    required String userId,
    required LocationModel companyLocation,
    ShiftModel? userShift,
  }) async {
    try {
      // Validate location first
      final locationResult = await _locationService.validateLocationForAttendance(companyLocation);
      if (!locationResult.isValid) {
        return AttendanceResult(
          success: false,
          message: locationResult.message,
          requiresPermission: locationResult.requiresPermission,
          requiresLocationService: locationResult.requiresLocationService,
        );
      }

      // Get today's attendance record
      final existingAttendance = await _firestoreService.getTodayAttendance(userId);
      if (existingAttendance == null) {
        return AttendanceResult(
          success: false,
          message: 'No check-in record found for today',
        );
      }

      if (!existingAttendance.hasCheckedIn) {
        return AttendanceResult(
          success: false,
          message: 'You need to check in first',
        );
      }

      if (existingAttendance.hasCheckedOut) {
        return AttendanceResult(
          success: false,
          message: 'You have already checked out today',
          attendance: existingAttendance,
        );
      }

      final now = DateTime.now();
      
      // Calculate working minutes
      final totalMinutes = TimeCalculator.calculateWorkingMinutes(
        existingAttendance.checkInTime!,
        now,
      );

      // Update attendance record
      final updatedAttendance = existingAttendance.copyWith(
        checkOutTime: now,
        totalMinutes: totalMinutes,
        checkOutLatitude: locationResult.currentLatitude,
        checkOutLongitude: locationResult.currentLongitude,
      );

      // Save to database
      final success = await _firestoreService.updateAttendance(updatedAttendance);

      if (success) {
        return AttendanceResult(
          success: true,
          message: 'Check-out successful',
          attendance: updatedAttendance,
        );
      } else {
        return AttendanceResult(
          success: false,
          message: 'Failed to save check-out record',
        );
      }
    } catch (e) {
      print('Error during check-out: $e');
      return AttendanceResult(
        success: false,
        message: 'Error during check-out: $e',
      );
    }
  }

  /// Get user's attendance history
  Future<List<AttendanceModel>> getUserAttendanceHistory(String userId) async {
    return await _firestoreService.getUserAttendance(userId);
  }

  /// Get today's attendance for user
  Future<AttendanceModel?> getTodayAttendance(String userId) async {
    return await _firestoreService.getTodayAttendance(userId);
  }

  /// Get attendance by date range
  Future<List<AttendanceModel>> getAttendanceByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _firestoreService.getAttendanceByDateRange(startDate, endDate);
  }

  /// Get attendance statistics for user
  Future<AttendanceStatistics> getUserAttendanceStatistics(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final attendanceRecords = await _firestoreService.getAttendanceByDateRange(startDate, endDate);
      final userRecords = attendanceRecords.where((record) => record.userId == userId).toList();

      int totalDays = userRecords.length;
      int presentDays = userRecords.where((record) => record.status == 'present').length;
      int lateDays = userRecords.where((record) => record.status == 'late').length;
      int absentDays = userRecords.where((record) => record.status == 'absent').length;
      
      int totalWorkingMinutes = userRecords.fold(0, (sum, record) => sum + record.totalMinutes);
      double totalWorkingHours = totalWorkingMinutes / 60.0;

      return AttendanceStatistics(
        totalDays: totalDays,
        presentDays: presentDays,
        lateDays: lateDays,
        absentDays: absentDays,
        totalWorkingHours: totalWorkingHours,
        averageWorkingHours: totalDays > 0 ? totalWorkingHours / totalDays : 0,
        attendancePercentage: totalDays > 0 ? (presentDays + lateDays) / totalDays * 100 : 0,
      );
    } catch (e) {
      print('Error getting attendance statistics: $e');
      return AttendanceStatistics.empty();
    }
  }

  /// Mark employee as absent (admin action)
  Future<bool> markAbsent(String userId) async {
    try {
      final today = DateTime.now();
      
      final attendance = AttendanceModel(
        attendanceId: '${userId}_${DateFormat('yyyy_MM_dd').format(today)}',
        userId: userId,
        date: DateTime(today.year, today.month, today.day),
        status: 'absent',
        checkInTime: null,
        checkOutTime: null,
        totalMinutes: 0,
        notes: 'Marked absent by admin - ${FirebaseAuth.instance.currentUser?.email}',
      );

      await _firestoreService.createAttendance(attendance);
      return true;
    } catch (e) {
      print('Error marking absent: $e');
      return false;
    }
  }

  /// Get attendance history for a user within date range
  Future<List<AttendanceModel>> getAttendanceHistory(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _firestoreService.getAttendanceHistory(
        userId,
        startDate,
        endDate,
      );
    } catch (e) {
      print('Error getting attendance history: $e');
      return [];
    }
  }

  /// Get all attendance for a specific date (admin function)
  Future<List<AttendanceModel>> getAttendanceByDate(DateTime date) async {
    return await _firestoreService.getAttendanceByDate(date);
  }

  /// Get attendance summary for all employees
  Future<List<AttendanceSummary>> getAttendanceSummary(DateTime date) async {
    try {
      final attendanceRecords = await getAttendanceByDate(date);
      final Map<String, AttendanceModel> userAttendanceMap = {};
      
      for (final record in attendanceRecords) {
        userAttendanceMap[record.userId] = record;
      }

      // Get all active employees
      final firestoreService = FirestoreService();
      final allUsers = await firestoreService.getAllUsers();
      final employees = allUsers.where((user) => user.isEmployee && user.isActive).toList();

      final summaries = <AttendanceSummary>[];
      
      for (final employee in employees) {
        final attendance = userAttendanceMap[employee.userId];
        summaries.add(AttendanceSummary(
          user: employee,
          attendance: attendance,
          status: attendance?.status ?? 'absent',
        ));
      }

      return summaries;
    } catch (e) {
      print('Error getting attendance summary: $e');
      return [];
    }
  }

  /// Validate check-in/check-out time against shift
  bool isValidAttendanceTime(DateTime time, ShiftModel shift, bool isCheckIn) {
    final expectedTime = isCheckIn 
        ? shift.getExpectedCheckInTime()
        : shift.getExpectedCheckOutTime();
    
    final gracePeriod = Duration(minutes: shift.gracePeriodMinutes);
    
    if (isCheckIn) {
      // Allow check-in from 1 hour before expected time to grace period after
      final earliestTime = expectedTime.subtract(const Duration(hours: 1));
      final latestTime = expectedTime.add(gracePeriod);
      return time.isAfter(earliestTime) && time.isBefore(latestTime);
    } else {
      // Allow check-out from expected time onwards
      return time.isAfter(expectedTime);
    }
  }

}

class AttendanceResult {
  final bool success;
  final String message;
  final AttendanceModel? attendance;
  final bool requiresPermission;
  final bool requiresLocationService;

  AttendanceResult({
    required this.success,
    required this.message,
    this.attendance,
    this.requiresPermission = false,
    this.requiresLocationService = false,
  });
}

class AttendanceStatistics {
  final int totalDays;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final double totalWorkingHours;
  final double averageWorkingHours;
  final double attendancePercentage;

  AttendanceStatistics({
    required this.totalDays,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.totalWorkingHours,
    required this.averageWorkingHours,
    required this.attendancePercentage,
  });

  factory AttendanceStatistics.empty() {
    return AttendanceStatistics(
      totalDays: 0,
      presentDays: 0,
      lateDays: 0,
      absentDays: 0,
      totalWorkingHours: 0,
      averageWorkingHours: 0,
      attendancePercentage: 0,
    );
  }
}

class AttendanceSummary {
  final UserModel user;
  final AttendanceModel? attendance;
  final String status;

  AttendanceSummary({
    required this.user,
    this.attendance,
    required this.status,
  });
}
