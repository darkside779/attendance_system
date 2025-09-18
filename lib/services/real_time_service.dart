import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

class RealTimeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream today's attendance for real-time monitoring
  Stream<List<AttendanceModel>> getTodayAttendanceStream() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AttendanceModel.fromDocument(doc))
            .toList());
  }

  /// Stream all active employees for management
  Stream<List<UserModel>> getActiveEmployeesStream() {
    return _firestore
        .collection('users')
        .where('isActive', isEqualTo: true)
        .where('role', isEqualTo: 'employee')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromDocument(doc))
            .toList());
  }

  /// Stream attendance for specific date range
  Stream<List<AttendanceModel>> getAttendanceRangeStream({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) {
    Query query = _firestore.collection('attendance');

    // Add date filters
    query = query
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    // Add user filter if specified
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AttendanceModel.fromDocument(doc))
            .toList());
  }

  /// Stream attendance statistics
  Stream<Map<String, dynamic>> getTodayStatsStream() {
    return getTodayAttendanceStream().map((attendanceList) {
      final stats = <String, dynamic>{
        'total': attendanceList.length,
        'present': 0,
        'late': 0,
        'absent': 0,
        'checkedIn': 0,
        'checkedOut': 0,
      };

      for (final attendance in attendanceList) {
        switch (attendance.status.toLowerCase()) {
          case 'present':
            stats['present']++;
            break;
          case 'late':
            stats['late']++;
            break;
          case 'absent':
            stats['absent']++;
            break;
        }

        if (attendance.hasCheckedIn) {
          stats['checkedIn']++;
        }
        if (attendance.hasCheckedOut) {
          stats['checkedOut']++;
        }
      }

      return stats;
    });
  }

  /// Stream late arrivals for admin alerts
  Stream<List<AttendanceModel>> getLateArrivalsStream() {
    return getTodayAttendanceStream().map((attendanceList) =>
        attendanceList.where((a) => a.status.toLowerCase() == 'late').toList());
  }

  /// Stream employees currently checked in
  Stream<List<AttendanceModel>> getCurrentlyCheckedInStream() {
    return getTodayAttendanceStream().map((attendanceList) => attendanceList
        .where((a) => a.hasCheckedIn && !a.hasCheckedOut)
        .toList());
  }
}
