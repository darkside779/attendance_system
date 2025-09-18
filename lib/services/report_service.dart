import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class ReportService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Generate attendance report for date range
  Future<Map<String, dynamic>> generateAttendanceReport({
    required DateTime startDate,
    required DateTime endDate,
    String? departmentFilter,
    String? positionFilter,
  }) async {
    try {
      // Get attendance data for the date range
      final attendanceData = await _getAttendanceDataForRange(startDate, endDate);
      final employees = await _getAllEmployees();

      // Process data into report format
      final reportData = _processAttendanceData(
        attendanceData,
        employees,
        startDate,
        endDate,
        departmentFilter: departmentFilter,
        positionFilter: positionFilter,
      );

      return {
        'success': true,
        'data': reportData,
        'generated_at': DateTime.now().toIso8601String(),
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        }
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to generate report: $e',
      };
    }
  }

  /// Get attendance data for date range
  Future<List<AttendanceModel>> _getAttendanceDataForRange(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    // This would typically use Firestore queries with date range
    // For now, returning placeholder data structure
    return [];
  }

  /// Get all employees
  Future<List<UserModel>> _getAllEmployees() async {
    // This would query all employees from Firestore
    return [];
  }

  /// Process raw data into structured report
  Map<String, dynamic> _processAttendanceData(
    List<AttendanceModel> attendanceData,
    List<UserModel> employees,
    DateTime startDate,
    DateTime endDate, {
    String? departmentFilter,
    String? positionFilter,
  }) {
    final Map<String, Map<String, dynamic>> employeeStats = {};
    final Map<String, int> dailyStats = {};
    
    // Initialize employee stats
    for (final employee in employees) {
      // Apply filters if specified
      if (departmentFilter != null && departmentFilter.isNotEmpty) {
        // Assuming department is stored in position or a separate field
        if (!employee.position.toLowerCase().contains(departmentFilter.toLowerCase())) {
          continue;
        }
      }
      
      if (positionFilter != null && positionFilter.isNotEmpty) {
        if (!employee.position.toLowerCase().contains(positionFilter.toLowerCase())) {
          continue;
        }
      }

      employeeStats[employee.userId] = {
        'name': employee.name,
        'email': employee.email,
        'position': employee.position,
        'total_days': 0,
        'present_days': 0,
        'late_days': 0,
        'absent_days': 0,
        'total_hours': 0.0,
        'average_check_in_time': null,
        'attendance_percentage': 0.0,
        'punctuality_percentage': 0.0,
      };
    }

    // Process attendance data
    for (final attendance in attendanceData) {
      if (!employeeStats.containsKey(attendance.userId)) continue;

      final stats = employeeStats[attendance.userId]!;
      stats['total_days']++;

      switch (attendance.status.toLowerCase()) {
        case 'present':
          stats['present_days']++;
          break;
        case 'late':
          stats['late_days']++;
          break;
        case 'absent':
          stats['absent_days']++;
          break;
      }

      if (attendance.totalMinutes > 0) {
        stats['total_hours'] += attendance.totalMinutes / 60.0;
      }

      // Daily statistics
      final dateKey = attendance.date.toString().split(' ')[0];
      dailyStats[dateKey] = (dailyStats[dateKey] ?? 0) + 1;
    }

    // Calculate percentages and averages
    for (final stats in employeeStats.values) {
      final totalDays = stats['total_days'] as int;
      final presentDays = stats['present_days'] as int;
      final lateDays = stats['late_days'] as int;
      
      if (totalDays > 0) {
        stats['attendance_percentage'] = 
            ((presentDays + lateDays) / totalDays * 100).toDouble();
      }
      
      if (presentDays + lateDays > 0) {
        stats['punctuality_percentage'] = 
            (presentDays / (presentDays + lateDays) * 100).toDouble();
      }
    }

    // Calculate overall statistics
    final totalEmployees = employeeStats.length;
    int totalPresentDays = 0;
    int totalLateDays = 0;
    int totalAbsentDays = 0;
    double totalHours = 0.0;

    for (final stats in employeeStats.values) {
      totalPresentDays += stats['present_days'] as int;
      totalLateDays += stats['late_days'] as int;
      totalAbsentDays += stats['absent_days'] as int;
      totalHours += stats['total_hours'] as double;
    }

    return {
      'summary': {
        'total_employees': totalEmployees,
        'total_present_days': totalPresentDays,
        'total_late_days': totalLateDays,
        'total_absent_days': totalAbsentDays,
        'total_hours_worked': totalHours,
        'average_attendance_rate': totalEmployees > 0 
            ? (totalPresentDays + totalLateDays) / 
              (totalPresentDays + totalLateDays + totalAbsentDays) * 100
            : 0.0,
        'average_punctuality_rate': (totalPresentDays + totalLateDays) > 0
            ? totalPresentDays / (totalPresentDays + totalLateDays) * 100
            : 0.0,
      },
      'employee_details': employeeStats,
      'daily_stats': dailyStats,
      'filters_applied': {
        'department': departmentFilter,
        'position': positionFilter,
      }
    };
  }

  /// Export report to CSV format
  Future<String> exportToCSV(Map<String, dynamic> reportData) async {
    try {
      final employeeDetails = reportData['employee_details'] as Map<String, dynamic>;
      final summary = reportData['summary'] as Map<String, dynamic>;
      
      final List<String> csvLines = [];
      
      // Add header
      csvLines.add('Employee Name,Email,Position,Total Days,Present,Late,Absent,Total Hours,Attendance %,Punctuality %');
      
      // Add employee data
      for (final employeeData in employeeDetails.values) {
        final data = employeeData as Map<String, dynamic>;
        csvLines.add([
          data['name'],
          data['email'],
          data['position'],
          data['total_days'].toString(),
          data['present_days'].toString(),
          data['late_days'].toString(),
          data['absent_days'].toString(),
          data['total_hours'].toStringAsFixed(1),
          data['attendance_percentage'].toStringAsFixed(1),
          data['punctuality_percentage'].toStringAsFixed(1),
        ].join(','));
      }
      
      // Add summary section
      csvLines.add('');
      csvLines.add('SUMMARY');
      csvLines.add('Total Employees,${summary['total_employees']}');
      csvLines.add('Average Attendance Rate,${summary['average_attendance_rate'].toStringAsFixed(1)}%');
      csvLines.add('Average Punctuality Rate,${summary['average_punctuality_rate'].toStringAsFixed(1)}%');
      csvLines.add('Total Hours Worked,${summary['total_hours_worked'].toStringAsFixed(1)}');
      
      return csvLines.join('\n');
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  /// Save CSV report to file
  Future<String> saveCSVReport(String csvContent, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${directory.path}/reports');
      
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }
      
      final file = File('${reportsDir.path}/$fileName.csv');
      await file.writeAsString(csvContent);
      
      return file.path;
    } catch (e) {
      throw Exception('Failed to save CSV report: $e');
    }
  }

  /// Generate monthly summary report
  Future<Map<String, dynamic>> generateMonthlySummary({
    required int year,
    required int month,
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0); // Last day of month
    
    return await generateAttendanceReport(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Generate employee individual report
  Future<Map<String, dynamic>> generateEmployeeReport({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Get employee data
      final employee = await _firestoreService.getUser(userId);
      if (employee == null) {
        return {
          'success': false,
          'error': 'Employee not found',
        };
      }

      // Get attendance data for this employee
      final attendanceData = await _getEmployeeAttendanceForRange(
        userId, 
        startDate, 
        endDate,
      );

      // Process individual data
      final processedData = _processIndividualAttendanceData(
        employee,
        attendanceData,
        startDate,
        endDate,
      );

      return {
        'success': true,
        'employee': employee.toJson(),
        'data': processedData,
        'generated_at': DateTime.now().toIso8601String(),
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        }
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to generate employee report: $e',
      };
    }
  }

  /// Get attendance data for specific employee
  Future<List<AttendanceModel>> _getEmployeeAttendanceForRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // This would query Firestore for specific employee attendance
    return [];
  }

  /// Process individual employee attendance data
  Map<String, dynamic> _processIndividualAttendanceData(
    UserModel employee,
    List<AttendanceModel> attendanceData,
    DateTime startDate,
    DateTime endDate,
  ) {
    final stats = {
      'total_days': 0,
      'present_days': 0,
      'late_days': 0,
      'absent_days': 0,
      'total_hours': 0.0,
      'daily_records': <Map<String, dynamic>>[],
    };

    for (final attendance in attendanceData) {
      stats['total_days'] = (stats['total_days'] as int) + 1;

      switch (attendance.status.toLowerCase()) {
        case 'present':
          stats['present_days'] = (stats['present_days'] as int) + 1;
          break;
        case 'late':
          stats['late_days'] = (stats['late_days'] as int) + 1;
          break;
        case 'absent':
          stats['absent_days'] = (stats['absent_days'] as int) + 1;
          break;
      }

      if (attendance.totalMinutes > 0) {
        stats['total_hours'] = (stats['total_hours'] as double) + (attendance.totalMinutes / 60.0);
      }

      // Add daily record
      (stats['daily_records'] as List<Map<String, dynamic>>).add({
        'date': attendance.date.toIso8601String(),
        'status': attendance.status,
        'check_in_time': attendance.checkInTime?.toIso8601String(),
        'check_out_time': attendance.checkOutTime?.toIso8601String(),
        'total_minutes': attendance.totalMinutes,
        'total_hours': attendance.totalMinutes / 60.0,
      });
    }

    // Calculate percentages
    final totalDays = stats['total_days'] as int;
    final presentDays = stats['present_days'] as int;
    final lateDays = stats['late_days'] as int;

    stats['attendance_percentage'] = totalDays > 0 
        ? ((presentDays + lateDays) / totalDays * 100).toDouble()
        : 0.0;
    
    stats['punctuality_percentage'] = (presentDays + lateDays) > 0
        ? (presentDays / (presentDays + lateDays) * 100).toDouble()
        : 0.0;

    stats['average_hours_per_day'] = totalDays > 0
        ? (stats['total_hours'] as double) / totalDays
        : 0.0;

    return stats;
  }
}
