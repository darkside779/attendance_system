// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../models/settings_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Users Collection Operations
  Future<bool> createUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.userId).set(user.toJson());
      return true;
    } catch (e) {
      print('Error creating user: $e');
      return false;
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<bool> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.userId)
          .update(user.toJson());
      return true;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) => UserModel.fromDocument(doc)).toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  Stream<List<UserModel>> getUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromDocument(doc)).toList());
  }

  // Attendance Collection Operations
  Future<bool> createAttendance(AttendanceModel attendance) async {
    try {
      await _firestore
          .collection('attendance')
          .doc(attendance.attendanceId)
          .set(attendance.toJson());
      return true;
    } catch (e) {
      print('Error creating attendance: $e');
      return false;
    }
  }

  Future<AttendanceModel?> getAttendance(String attendanceId) async {
    try {
      final doc =
          await _firestore.collection('attendance').doc(attendanceId).get();
      if (doc.exists) {
        return AttendanceModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error getting attendance: $e');
      return null;
    }
  }

  Future<bool> updateAttendance(AttendanceModel attendance) async {
    try {
      await _firestore
          .collection('attendance')
          .doc(attendance.attendanceId)
          .update(attendance.toJson());
      return true;
    } catch (e) {
      print('Error updating attendance: $e');
      return false;
    }
  }

  Future<bool> deleteAttendance(String attendanceId) async {
    try {
      await _firestore.collection('attendance').doc(attendanceId).delete();
      return true;
    } catch (e) {
      print('Error deleting attendance: $e');
      return false;
    }
  }

  // Get attendance records for a specific user
  Future<List<AttendanceModel>> getUserAttendance(String userId) async {
    try {
      print('🔍 Getting user attendance history for: $userId');
      
      // Use simple query to avoid composite index requirement
      final snapshot = await _firestore
          .collection('attendance')
          .orderBy('checkInTime', descending: true)
          .limit(100) // Get more records to ensure we get all user's data
          .get();

      print('📊 Found ${snapshot.docs.length} total attendance records');

      // Filter locally by userId to avoid composite index
      final userRecords = <AttendanceModel>[];
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final recordUserId = data['userId'] as String?;
          
          if (recordUserId == userId) {
            final attendance = AttendanceModel.fromDocument(doc);
            userRecords.add(attendance);
            
            print('✅ Found user record: ${doc.id}');
            print('  - Date: ${attendance.date}');
            print('  - Status: ${attendance.status}');
            print('  - CheckIn: ${attendance.checkInTime}');
            print('  - CheckOut: ${attendance.checkOutTime}');
          }
        } catch (e) {
          print('⚠️ Error processing record ${doc.id}: $e');
          continue;
        }
      }

      print('📊 Filtered to ${userRecords.length} records for user');
      
      // Sort by date (most recent first)
      userRecords.sort((a, b) => b.date.compareTo(a.date));
      
      return userRecords;
    } catch (e) {
      print('❌ Error getting user attendance: $e');
      return [];
    }
  }

  // Get attendance records for a specific date
  Future<List<AttendanceModel>> getAttendanceByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      return snapshot.docs
          .map((doc) => AttendanceModel.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error getting attendance by date: $e');
      return [];
    }
  }

  // Get attendance records for a date range
  Future<List<AttendanceModel>> getAttendanceByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      print(
          '🔍 Firestore: Querying attendance from ${startDate} to ${endDate}');

      // Use simple query to avoid composite index requirement
      print('🔄 Getting recent attendance records...');
      final snapshot = await _firestore
          .collection('attendance')
          .orderBy('checkInTime', descending: true)
          .limit(50) // Get more records to ensure we find the date range
          .get();

      print('📊 Firestore: Found ${snapshot.docs.length} documents');

      // Filter locally by date range to avoid composite index
      final results = <AttendanceModel>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final checkInTime = (data['checkInTime'] as Timestamp?)?.toDate();
          final dateField = (data['date'] as Timestamp?)?.toDate();

          // Check if record falls within date range
          bool inRange = false;

          if (checkInTime != null) {
            inRange = checkInTime
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                checkInTime.isBefore(endDate.add(const Duration(days: 1)));
          } else if (dateField != null) {
            inRange = dateField
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                dateField.isBefore(endDate.add(const Duration(days: 1)));
          }

          if (inRange) {
            final attendance = AttendanceModel.fromDocument(doc);
            results.add(attendance);

            print('  ✅ Document ID: ${doc.id}');
            print('    Date: ${doc.data()['date']}');
            print('    CheckInTime: ${doc.data()['checkInTime']}');
            print('    Status: ${doc.data()['status']}');
            print('    UserId: ${doc.data()['userId']}');
          }
        } catch (e) {
          print('⚠️ Error processing record ${doc.id}: $e');
          continue;
        }
      }

      print('📊 Filtered to ${results.length} records in date range');
      return results;
    } catch (e) {
      print('❌ Firestore Error getting attendance by date range: $e');
      return [];
    }
  }

  /// Get attendance history for a user within date range
  Future<List<AttendanceModel>> getAttendanceHistory(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AttendanceModel.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error getting attendance history: $e');
      return [];
    }
  }

  // Get user's attendance for today
  Future<AttendanceModel?> getTodayAttendance(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      print('🔍 Getting today attendance for user: $userId');
      print('🔍 Current time: $today');
      print('🔍 Looking for today: ${startOfDay}');

      // Use a simple approach: get ALL recent records and filter locally
      // This completely avoids any composite index requirement
      print('🔄 Getting ALL recent attendance records...');
      final snapshot = await _firestore
          .collection('attendance')
          .orderBy('checkInTime', descending: true)
          .limit(20) // Get recent records from all users
          .get();

      print('📊 Found ${snapshot.docs.length} attendance records total');

      // Find today's record for this user by checking each one
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final recordUserId = data['userId'] as String?;
          final checkInTime = (data['checkInTime'] as Timestamp?)?.toDate();
          final dateField = (data['date'] as Timestamp?)?.toDate();

          // Skip if not this user's record
          if (recordUserId != userId) {
            continue;
          }

          print('📄 Checking user record: ${doc.id}');
          print('  - UserId: $recordUserId');
          print('  - CheckInTime: $checkInTime');
          print('  - Date: $dateField');

          // Check if this record is from today using checkInTime
          if (checkInTime != null) {
            final isToday = checkInTime.year == today.year &&
                checkInTime.month == today.month &&
                checkInTime.day == today.day;

            print('  - Is from today: $isToday');

            if (isToday) {
              print('✅ Found today\'s attendance record!');
              print('  - Document ID: ${doc.id}');
              print('  - CheckInTime: $checkInTime');
              print('  - CheckOutTime: ${data['checkOutTime']}');
              print('  - Status: ${data['status']}');

              final attendance = AttendanceModel.fromDocument(doc);
              print(
                  '✅ Parsed attendance: hasCheckedIn=${attendance.hasCheckedIn}, hasCheckedOut=${attendance.hasCheckedOut}');
              return attendance;
            }
          }

          // Also check using date field as fallback
          if (dateField != null) {
            final isToday = dateField.year == today.year &&
                dateField.month == today.month &&
                dateField.day == today.day;

            if (isToday) {
              print('✅ Found today\'s attendance via date field!');
              final attendance = AttendanceModel.fromDocument(doc);
              print(
                  '✅ Parsed attendance: hasCheckedIn=${attendance.hasCheckedIn}, hasCheckedOut=${attendance.hasCheckedOut}');
              return attendance;
            }
          }
        } catch (e) {
          print('⚠️ Error processing record ${doc.id}: $e');
          continue;
        }
      }

      print('❌ No attendance record found for today');
      return null;
    } catch (e) {
      print('❌ Error getting today attendance: $e');
      return null;
    }
  }

  Stream<List<AttendanceModel>> getAttendanceStream() {
    return _firestore
        .collection('attendance')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AttendanceModel.fromDocument(doc))
            .toList());
  }

  Stream<List<AttendanceModel>> getUserAttendanceStream(String userId) {
    return _firestore
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AttendanceModel.fromDocument(doc))
            .toList());
  }

  // Settings Collection Operations
  Future<bool> createSettings(SettingsModel settings) async {
    try {
      await _firestore
          .collection('settings')
          .doc(settings.companyId)
          .set(settings.toJson());
      return true;
    } catch (e) {
      print('Error creating settings: $e');
      return false;
    }
  }

  Future<SettingsModel?> getSettings(String companyId) async {
    try {
      final doc = await _firestore.collection('settings').doc(companyId).get();
      if (doc.exists) {
        return SettingsModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error getting settings: $e');
      return null;
    }
  }

  Future<SettingsModel?> getDefaultSettings() async {
    try {
      final snapshot = await _firestore.collection('settings').limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        return SettingsModel.fromDocument(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting default settings: $e');
      return null;
    }
  }

  Future<bool> updateSettings(SettingsModel settings) async {
    try {
      await _firestore
          .collection('settings')
          .doc(settings.companyId)
          .update(settings.toJson());
      return true;
    } catch (e) {
      print('Error updating settings: $e');
      return false;
    }
  }

  Stream<SettingsModel?> getSettingsStream(String companyId) {
    return _firestore
        .collection('settings')
        .doc(companyId)
        .snapshots()
        .map((doc) => doc.exists ? SettingsModel.fromDocument(doc) : null);
  }

  // Utility methods
  Future<bool> batchWrite(List<Map<String, dynamic>> operations) async {
    try {
      final batch = _firestore.batch();

      for (final operation in operations) {
        final collection = operation['collection'] as String;
        final docId = operation['docId'] as String;
        final data = operation['data'] as Map<String, dynamic>;
        final operationType =
            operation['type'] as String; // 'create', 'update', 'delete'

        final docRef = _firestore.collection(collection).doc(docId);

        switch (operationType) {
          case 'create':
            batch.set(docRef, data);
            break;
          case 'update':
            batch.update(docRef, data);
            break;
          case 'delete':
            batch.delete(docRef);
            break;
        }
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error in batch write: $e');
      return false;
    }
  }

  // Get collection document count
  Future<int> getCollectionCount(String collectionName) async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting collection count: $e');
      return 0;
    }
  }
}
