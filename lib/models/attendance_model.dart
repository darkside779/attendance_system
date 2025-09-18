import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String attendanceId;
  final String userId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int totalMinutes;
  final String status; // 'present', 'late', 'absent'
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String? notes;

  AttendanceModel({
    required this.attendanceId,
    required this.userId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.totalMinutes = 0,
    required this.status,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.notes,
  });

  // Convert AttendanceModel to Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'attendanceId': attendanceId,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'totalMinutes': totalMinutes,
      'status': status,
      'checkInLatitude': checkInLatitude,
      'checkInLongitude': checkInLongitude,
      'checkOutLatitude': checkOutLatitude,
      'checkOutLongitude': checkOutLongitude,
      'notes': notes,
    };
  }

  // Create AttendanceModel from Firestore document
  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      attendanceId: json['attendanceId'] ?? '',
      userId: json['userId'] ?? '',
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      checkInTime: (json['checkInTime'] as Timestamp?)?.toDate(),
      checkOutTime: (json['checkOutTime'] as Timestamp?)?.toDate(),
      totalMinutes: json['totalMinutes'] ?? 0,
      status: json['status'] ?? 'absent',
      checkInLatitude: json['checkInLatitude']?.toDouble(),
      checkInLongitude: json['checkInLongitude']?.toDouble(),
      checkOutLatitude: json['checkOutLatitude']?.toDouble(),
      checkOutLongitude: json['checkOutLongitude']?.toDouble(),
      notes: json['notes'],
    );
  }

  // Create AttendanceModel from Firestore DocumentSnapshot
  factory AttendanceModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }
    return AttendanceModel.fromJson({...data, 'attendanceId': doc.id});
  }

  // Copy with method for updating attendance data
  AttendanceModel copyWith({
    String? attendanceId,
    String? userId,
    DateTime? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    int? totalMinutes,
    String? status,
    double? checkInLatitude,
    double? checkInLongitude,
    double? checkOutLatitude,
    double? checkOutLongitude,
    String? notes,
  }) {
    return AttendanceModel(
      attendanceId: attendanceId ?? this.attendanceId,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      status: status ?? this.status,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
      notes: notes ?? this.notes,
    );
  }

  // Get working hours as double
  double get workingHours => totalMinutes / 60.0;

  // Get working hours method (for compatibility)
  String getWorkingHours() => formattedWorkingTime;

  // Get location string (for compatibility)
  String get location {
    if (checkInLatitude != null && checkInLongitude != null) {
      return 'Lat: ${checkInLatitude!.toStringAsFixed(4)}, Lng: ${checkInLongitude!.toStringAsFixed(4)}';
    }
    return 'Location not available';
  }

  // Check if user has checked in
  bool get hasCheckedIn => checkInTime != null;

  // Check if user has checked out
  bool get hasCheckedOut => checkOutTime != null;

  // Check if attendance is complete (both check-in and check-out)
  bool get isComplete => hasCheckedIn && hasCheckedOut;

  // Get formatted working time
  String get formattedWorkingTime {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  // Get status color based on attendance status
  String get statusColor {
    switch (status.toLowerCase()) {
      case 'present':
        return '#4CAF50'; // Green
      case 'late':
        return '#FF9800'; // Orange
      case 'absent':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Grey
    }
  }

  @override
  String toString() {
    return 'AttendanceModel(attendanceId: $attendanceId, userId: $userId, date: $date, status: $status, totalMinutes: $totalMinutes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceModel && other.attendanceId == attendanceId;
  }

  @override
  int get hashCode => attendanceId.hashCode;
}
