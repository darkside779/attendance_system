// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../services/real_time_service.dart';
import '../services/attendance_service.dart';

class AdminAttendanceProvider extends ChangeNotifier {
  final RealTimeService _realTimeService = RealTimeService();
  final AttendanceService _attendanceService = AttendanceService();

  // Real-time data streams
  StreamSubscription<List<AttendanceModel>>? _todayAttendanceSubscription;
  StreamSubscription<List<UserModel>>? _employeesSubscription;
  StreamSubscription<Map<String, dynamic>>? _statsSubscription;

  // Data state
  List<AttendanceModel> _todayAttendance = [];
  List<UserModel> _employees = [];
  Map<String, dynamic> _todayStats = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<AttendanceModel> get todayAttendance => _todayAttendance;
  List<UserModel> get employees => _employees;
  Map<String, dynamic> get todayStats => _todayStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Real-time statistics getters
  int get totalEmployees => _todayStats['total'] ?? 0;
  int get presentCount => _todayStats['present'] ?? 0;
  int get lateCount => _todayStats['late'] ?? 0;
  int get absentCount => _todayStats['absent'] ?? 0;
  int get checkedInCount => _todayStats['checkedIn'] ?? 0;
  int get checkedOutCount => _todayStats['checkedOut'] ?? 0;

  // Derived statistics
  double get attendancePercentage {
    if (totalEmployees == 0) return 0.0;
    return ((presentCount + lateCount) / totalEmployees * 100);
  }

  double get punctualityPercentage {
    final totalPresent = presentCount + lateCount;
    if (totalPresent == 0) return 0.0;
    return (presentCount / totalPresent * 100);
  }

  /// Initialize real-time monitoring
  void startRealTimeMonitoring() {
    _setLoading(true);

    // Subscribe to today's attendance
    _todayAttendanceSubscription = _realTimeService
        .getTodayAttendanceStream()
        .listen(
          (attendance) {
            _todayAttendance = attendance;
            _setLoading(false);
            notifyListeners();
          },
          onError: (error) {
            _setError('Failed to load attendance: $error');
            _setLoading(false);
          },
        );

    // Subscribe to employees
    _employeesSubscription = _realTimeService
        .getActiveEmployeesStream()
        .listen(
          (employees) {
            _employees = employees;
            notifyListeners();
          },
          onError: (error) {
            _setError('Failed to load employees: $error');
          },
        );

    // Subscribe to statistics
    _statsSubscription = _realTimeService
        .getTodayStatsStream()
        .listen(
          (stats) {
            _todayStats = stats;
            notifyListeners();
          },
          onError: (error) {
            _setError('Failed to load statistics: $error');
          },
        );
  }

  /// Stop real-time monitoring
  void stopRealTimeMonitoring() {
    _todayAttendanceSubscription?.cancel();
    _employeesSubscription?.cancel();
    _statsSubscription?.cancel();
    
    _todayAttendanceSubscription = null;
    _employeesSubscription = null;
    _statsSubscription = null;
  }

  /// Load monthly statistics
  Future<void> loadMonthlyStats() async {
    _setLoading(true);
    _clearError();

    try {
      final now = DateTime.now();
      DateTime(now.year, now.month + 1, 1)
          .subtract(const Duration(days: 1));

      // This would typically load comprehensive monthly data
      // For now, we'll use today's stats as placeholder
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load monthly statistics: $e');
      _setLoading(false);
    }
  }

  /// Get employee attendance details
  AttendanceModel? getEmployeeAttendance(String userId) {
    try {
      return _todayAttendance.firstWhere((attendance) => attendance.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Get employees who are currently checked in
  List<UserModel> get currentlyCheckedInEmployees {
    return _employees.where((employee) {
      final attendance = getEmployeeAttendance(employee.userId);
      return attendance?.hasCheckedIn == true && attendance?.hasCheckedOut == false;
    }).toList();
  }

  /// Get employees who are late today
  List<UserModel> get lateEmployees {
    return _employees.where((employee) {
      final attendance = getEmployeeAttendance(employee.userId);
      return attendance?.status.toLowerCase() == 'late';
    }).toList();
  }

  /// Get employees who are absent today
  List<UserModel> get absentEmployees {
    return _employees.where((employee) {
      final attendance = getEmployeeAttendance(employee.userId);
      return attendance?.status.toLowerCase() == 'absent' || attendance == null;
    }).toList();
  }

  /// Get employees who are present today (not late or absent)
  List<UserModel> get presentEmployees {
    return _employees.where((employee) {
      final attendance = getEmployeeAttendance(employee.userId);
      return attendance?.status.toLowerCase() == 'present';
    }).toList();
  }

  /// Get attendance history for a specific employee
  Future<List<AttendanceModel>> getEmployeeAttendanceHistory(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final attendanceHistory = await _attendanceService.getAttendanceHistory(
        userId,
        startDate,
        endDate,
      );
      return attendanceHistory;
    } catch (e) {
      print('Error getting employee attendance history: $e');
      rethrow;
    }
  }

  /// Mark employee as absent (admin action)
  Future<bool> markEmployeeAbsent(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _attendanceService.markAbsent(userId);
      _setLoading(false);
      return success;
    } catch (e) {
      _setError('Failed to mark employee absent: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Refresh data manually
  Future<void> refreshData() async {
    stopRealTimeMonitoring();
    await Future.delayed(const Duration(milliseconds: 500));
    startRealTimeMonitoring();
  }

  /// Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    stopRealTimeMonitoring();
    super.dispose();
  }
}
