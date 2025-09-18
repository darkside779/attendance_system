// ignore_for_file: unused_field, unused_import, avoid_types_as_parameter_names, avoid_print

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../services/attendance_service.dart';
import '../services/firestore_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  final FirestoreService _firestoreService = FirestoreService();
  
  AttendanceModel? _todayAttendance;
  List<AttendanceModel> _attendanceHistory = [];
  final Map<String, dynamic> _monthlyStats = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // Getters
  AttendanceModel? get todayAttendance => _todayAttendance;
  List<AttendanceModel> get attendanceHistory => _attendanceHistory;
  Map<String, dynamic> get monthlyStats => _monthlyStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  
  // Status getters
  bool get hasCheckedInToday => _todayAttendance?.hasCheckedIn ?? false;
  bool get hasCheckedOutToday => _todayAttendance?.hasCheckedOut ?? false;
  bool get canCheckIn => !hasCheckedInToday;
  bool get canCheckOut => hasCheckedInToday && !hasCheckedOutToday;

  /// Load today's attendance for user
  Future<void> loadTodayAttendance(String userId) async {
    // Use Future.microtask to avoid setState during build
    await Future.microtask(() async {
      _setLoading(true);
      _clearMessages();

      try {
        print('🔄 AttendanceProvider: Loading today attendance for user $userId');
        final attendance = await _attendanceService.getTodayAttendance(userId);
        _todayAttendance = attendance;
        
        if (attendance != null) {
          print('✅ AttendanceProvider: Loaded attendance');
          print('  - Has checked in: ${attendance.hasCheckedIn}');
          print('  - Has checked out: ${attendance.hasCheckedOut}');
          print('  - Can check in: $canCheckIn');
          print('  - Can check out: $canCheckOut');
          print('  - Status: ${attendance.status}');
        } else {
          print('❌ AttendanceProvider: No attendance record found');
        }
      } catch (e) {
        print('❌ AttendanceProvider error: $e');
        _setError('Failed to load today\'s attendance: $e');
      }
      
      _setLoading(false);
    });
  }

  /// Load user's attendance history
  Future<void> loadAttendanceHistory(String userId) async {
    // Use Future.microtask to avoid setState during build
    await Future.microtask(() async {
      _setLoading(true);
      _clearMessages();

      try {
        final history = await _attendanceService.getUserAttendanceHistory(userId);
        _attendanceHistory = history;
      } catch (e) {
        _setError('Failed to load attendance history: $e');
      }
      
      _setLoading(false);
    });
  }

  /// Check in user
  Future<bool> checkIn({
    required String userId,
    required LocationModel companyLocation,
    ShiftModel? userShift,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      final result = await _attendanceService.checkIn(
        userId: userId,
        companyLocation: companyLocation,
        userShift: userShift,
      );

      if (result.success) {
        _todayAttendance = result.attendance;
        _setSuccess(result.message);
        _setLoading(false);
        return true;
      } else {
        _setError(result.message);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Check-in failed: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Check out user
  Future<bool> checkOut({
    required String userId,
    required LocationModel companyLocation,
    ShiftModel? userShift,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      final result = await _attendanceService.checkOut(
        userId: userId,
        companyLocation: companyLocation,
        userShift: userShift,
      );

      if (result.success) {
        _todayAttendance = result.attendance;
        _setSuccess(result.message);
        _setLoading(false);
        return true;
      } else {
        _setError(result.message);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Check-out failed: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Get attendance statistics for user
  Future<AttendanceStatistics?> getAttendanceStatistics(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _setLoading(true);
    _clearMessages();

    try {
      final statistics = await _attendanceService.getUserAttendanceStatistics(
        userId,
        startDate,
        endDate,
      );
      _setLoading(false);
      return statistics;
    } catch (e) {
      _setError('Failed to get statistics: $e');
      _setLoading(false);
      return null;
    }
  }

  /// Get attendance by date range
  Future<List<AttendanceModel>> getAttendanceByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    _setLoading(true);
    _clearMessages();

    try {
      final records = await _attendanceService.getAttendanceByDateRange(
        startDate,
        endDate,
      );
      _setLoading(false);
      return records;
    } catch (e) {
      _setError('Failed to get attendance records: $e');
      _setLoading(false);
      return [];
    }
  }

  /// Refresh today's attendance
  Future<void> refreshTodayAttendance(String userId) async {
    await loadTodayAttendance(userId);
  }

  /// Refresh attendance history
  Future<void> refreshAttendanceHistory(String userId) async {
    await loadAttendanceHistory(userId);
  }

  /// Get working hours today
  String get todayWorkingHours {
    if (_todayAttendance == null) return '0h 0m';
    
    if (_todayAttendance!.hasCheckedOut) {
      return _todayAttendance!.formattedWorkingTime;
    } else if (_todayAttendance!.hasCheckedIn) {
      final now = DateTime.now();
      final minutes = now.difference(_todayAttendance!.checkInTime!).inMinutes;
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
    
    return '0h 0m';
  }

  /// Get today's status
  String get todayStatus {
    if (_todayAttendance == null) return 'Not checked in';
    
    if (_todayAttendance!.hasCheckedOut) {
      return 'Completed - ${_todayAttendance!.status}';
    } else if (_todayAttendance!.hasCheckedIn) {
      return 'Checked in - ${_todayAttendance!.status}';
    }
    
    return 'Not checked in';
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
    _successMessage = null;
    notifyListeners();
  }

  /// Set success message
  void _setSuccess(String success) {
    _successMessage = success;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear messages
  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Load monthly statistics for user
  Future<void> loadMonthlyStats(String userId) async {
    _setLoading(true);
    _clearMessages();

    try {
      final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final endOfMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
      
      final records = await getAttendanceByDateRange(startOfMonth, endOfMonth);
      _calculateMonthlyStats(records);
    } catch (e) {
      _setError('Failed to load monthly stats: $e');
    }
    
    _setLoading(false);
  }

  /// Calculate monthly statistics
  void _calculateMonthlyStats(List<AttendanceModel> records) {
    final total = records.length;
    final present = records.where((a) => a.status == 'present').length;
    final late = records.where((a) => a.status == 'late').length;
    final absent = records.where((a) => a.status == 'absent').length;
    
    final totalWorkingMinutes = records
        .where((a) => a.hasCheckedOut)
        .fold(0, (sum, a) => sum + a.totalMinutes);

    _monthlyStats.clear();
    _monthlyStats.addAll({
      'total': total,
      'present': present,
      'late': late,
      'absent': absent,
      'totalWorkingHours': (totalWorkingMinutes / 60).toStringAsFixed(1),
      'averageWorkingHours': total > 0 ? (totalWorkingMinutes / total / 60).toStringAsFixed(1) : '0.0',
    });
    
    notifyListeners();
  }

  /// Clear messages manually
  void clearMessages() {
    _clearMessages();
  }
}

/// Admin-specific attendance provider
class AdminAttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  
  List<AttendanceSummary> _todayAttendanceSummary = [];
  List<AttendanceModel> _allAttendanceRecords = [];
  List<AttendanceModel> _todayAttendance = [];
  List<UserModel> _employees = [];
  Map<String, dynamic> _todayStats = {};
  Map<String, dynamic> _monthlyStats = {};
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<AttendanceSummary> get todayAttendanceSummary => _todayAttendanceSummary;
  List<AttendanceModel> get allAttendanceRecords => _allAttendanceRecords;
  List<AttendanceModel> get todayAttendance => _todayAttendance;
  List<UserModel> get employees => _employees;
  Map<String, dynamic> get todayStats => _todayStats;
  Map<String, dynamic> get monthlyStats => _monthlyStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load today's attendance summary
  Future<void> loadTodayAttendanceSummary() async {
    _setLoading(true);
    _clearError();

    try {
      final summary = await _attendanceService.getAttendanceSummary(DateTime.now());
      _todayAttendanceSummary = summary;
    } catch (e) {
      _setError('Failed to load attendance summary: $e');
    }
    
    _setLoading(false);
  }

  /// Load attendance records for date range
  Future<void> loadAttendanceRecords(DateTime startDate, DateTime endDate) async {
    _setLoading(true);
    _clearError();

    try {
      final records = await _attendanceService.getAttendanceByDateRange(startDate, endDate);
      _allAttendanceRecords = records;
    } catch (e) {
      _setError('Failed to load attendance records: $e');
    }
    
    _setLoading(false);
  }

  /// Get attendance summary for specific date
  Future<List<AttendanceSummary>> getAttendanceSummaryForDate(DateTime date) async {
    _setLoading(true);
    _clearError();

    try {
      final summary = await _attendanceService.getAttendanceSummary(date);
      _setLoading(false);
      return summary;
    } catch (e) {
      _setError('Failed to get attendance summary: $e');
      _setLoading(false);
      return [];
    }
  }

  /// Mark user as absent
  Future<bool> markUserAbsent(String userId, DateTime date) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _attendanceService.markAbsent(userId);
      if (success) {
        // Refresh data
        await loadTodayAttendanceSummary();
      } else {
        _setError('Failed to mark user as absent');
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError('Error marking user absent: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Get statistics summary
  Map<String, int> get todayStatistics {
    final present = _todayAttendanceSummary.where((s) => s.status == 'present').length;
    final late = _todayAttendanceSummary.where((s) => s.status == 'late').length;
    final absent = _todayAttendanceSummary.where((s) => s.status == 'absent').length;
    final total = _todayAttendanceSummary.length;

    return {
      'total': total,
      'present': present,
      'late': late,
      'absent': absent,
    };
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

  /// Load today's attendance records
  Future<void> loadTodayAttendance() async {
    _setLoading(true);
    _clearError();

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      print('🔍 Loading attendance for: ${startOfDay.toString()} to ${endOfDay.toString()}');
      
      final records = await _attendanceService.getAttendanceByDateRange(
        startOfDay,
        endOfDay,
      );
      
      print('📊 Found ${records.length} attendance records');
      for (var record in records) {
        print('  - ${record.userId}: ${record.status} (Check-in: ${record.checkInTime})');
      }
      
      _todayAttendance = records;
      _calculateTodayStats();
      
      print('📈 Calculated stats: $_todayStats');
    } catch (e) {
      print('❌ Error loading today\'s attendance: $e');
      _setError('Failed to load today\'s attendance: $e');
    }
    
    _setLoading(false);
  }

  /// Load monthly statistics
  Future<void> loadMonthlyStats() async {
    _setLoading(true);
    _clearError();

    try {
      final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final endOfMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
      
      final records = await _attendanceService.getAttendanceByDateRange(
        startOfMonth,
        endOfMonth,
      );
      
      _calculateMonthlyStats(records);
    } catch (e) {
      _setError('Failed to load monthly stats: $e');
    }
    
    _setLoading(false);
  }

  /// Calculate today's statistics
  void _calculateTodayStats() {
    final total = _todayAttendance.length;
    final present = _todayAttendance.where((a) => a.status == 'present').length;
    final late = _todayAttendance.where((a) => a.status == 'late').length;
    final absent = _todayAttendance.where((a) => a.status == 'absent').length;

    _todayStats = {
      'total': total,
      'present': present,
      'late': late,
      'absent': absent,
      'onLeave': 0, // Placeholder for leave functionality
      'presentPercentage': total > 0 ? (present / total * 100).round() : 0,
    };
  }

  /// Calculate monthly statistics
  void _calculateMonthlyStats(List<AttendanceModel> records) {
    final total = records.length;
    final present = records.where((a) => a.status == 'present').length;
    final late = records.where((a) => a.status == 'late').length;
    final absent = records.where((a) => a.status == 'absent').length;
    
    final totalWorkingMinutes = records
        .where((a) => a.hasCheckedOut)
        .fold(0, (sum, a) => sum + a.totalMinutes);
    
    final averageWorkingHours = records.isNotEmpty 
        ? (totalWorkingMinutes / records.length / 60).toStringAsFixed(1)
        : '0.0';

    _monthlyStats = {
      'total': total,
      'present': present,
      'late': late,
      'absent': absent,
      'onLeave': 0, // Placeholder for leave functionality
      'presentPercentage': total > 0 ? (present / total * 100).round() : 0,
      'totalWorkingHours': (totalWorkingMinutes / 60).toStringAsFixed(1),
      'averageWorkingHours': averageWorkingHours,
    };
  }

  /// Clear error manually
  void clearError() {
    _clearError();
  }

  // Employee Management Methods
  
  /// Load all employees
  Future<void> loadEmployees() async {
    _setLoading(true);
    _clearError();

    try {
      // Load users from Firestore
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      _employees = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return UserModel.fromJson({...data, 'userId': doc.id});
      }).toList();
      
    } catch (e) {
      _setError('Failed to load employees: $e');
    }
    
    _setLoading(false);
  }

  /// Add new employee
  Future<bool> addEmployee(UserModel employee) async {
    _setLoading(true);
    _clearError();

    try {
      // Add to Firebase/Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(employee.userId)
          .set(employee.toJson());
      
      // Update local list
      _employees.add(employee);
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to add employee: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Update employee
  Future<bool> updateEmployee(UserModel employee) async {
    _setLoading(true);
    _clearError();

    try {
      // Update in Firebase/Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(employee.userId)
          .update(employee.toJson());
      
      // Update in local list
      final index = _employees.indexWhere((e) => e.userId == employee.userId);
      if (index != -1) {
        _employees[index] = employee;
        notifyListeners();
        _setLoading(false);
        return true;
      }
      _setError('Employee not found');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to update employee: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Delete employee
  Future<bool> deleteEmployee(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // Delete from Firebase/Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .delete();
      
      // Remove from local list
      _employees.removeWhere((e) => e.userId == userId);
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to delete employee: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Get employee by ID
  UserModel? getEmployeeById(String userId) {
    try {
      return _employees.firstWhere((e) => e.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Get employee attendance for today
  AttendanceModel? getEmployeeAttendance(String userId) {
    try {
      return _todayAttendance.firstWhere((a) => a.userId == userId);
    } catch (e) {
      return null;
    }
  }

}
