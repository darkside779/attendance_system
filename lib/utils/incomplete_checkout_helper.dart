// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../models/shift_model.dart';
import '../models/user_model.dart';

/// Helper class to manage incomplete checkouts
class IncompleteCheckoutHelper {
  static const String _attendanceCollection = 'attendance';
  static const String _usersCollection = 'users';
  
  /// Find all incomplete checkouts (checked in but not checked out)
  static Future<List<AttendanceModel>> findIncompleteCheckouts({
    DateTime? beforeDate,
    String? userId,
  }) async {
    try {
      print('🔍 Searching for incomplete checkouts...');
      
      Query query = FirebaseFirestore.instance
          .collection(_attendanceCollection)
          .where('checkInTime', isNotEqualTo: null)
          .where('checkOutTime', isEqualTo: null);
      
      // Filter by user if specified
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      // Filter by date if specified
      if (beforeDate != null) {
        query = query.where('date', isLessThan: Timestamp.fromDate(beforeDate));
      }
      
      final snapshot = await query.get();
      final incompleteCheckouts = snapshot.docs
          .map((doc) => AttendanceModel.fromDocument(doc))
          .toList();
      
      print('📋 Found ${incompleteCheckouts.length} incomplete checkouts');
      for (var checkout in incompleteCheckouts) {
        print('  - User: ${checkout.userId}, Date: ${checkout.date}, Check-in: ${checkout.checkInTime}');
      }
      
      return incompleteCheckouts;
    } catch (e) {
      print('❌ Error finding incomplete checkouts: $e');
      return [];
    }
  }
  
  /// Check if user has any incomplete checkouts
  static Future<AttendanceModel?> getUserIncompleteCheckout(String userId) async {
    try {
      final incompleteCheckouts = await findIncompleteCheckouts(userId: userId);
      return incompleteCheckouts.isNotEmpty ? incompleteCheckouts.first : null;
    } catch (e) {
      print('❌ Error checking user incomplete checkout: $e');
      return null;
    }
  }
  
  /// Get users with incomplete checkouts for today and previous days
  static Future<List<UserModel>> getUsersForIncompleteCheckouts() async {
    try {
      // Get incomplete checkouts from yesterday and before
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final incompleteCheckouts = await findIncompleteCheckouts(beforeDate: yesterday);
      
      if (incompleteCheckouts.isEmpty) return [];
      
      // Get unique user IDs
      final userIds = incompleteCheckouts.map((a) => a.userId).toSet().toList();
      
      // Fetch user details
      final List<UserModel> users = [];
      for (String userId in userIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection(_usersCollection)
              .doc(userId)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            users.add(UserModel.fromJson({...userData, 'userId': userId}));
          }
        } catch (e) {
          print('❌ Error fetching user $userId: $e');
        }
      }
      
      return users;
    } catch (e) {
      print('❌ Error getting users for incomplete checkouts: $e');
      return [];
    }
  }
  
  /// Auto-complete checkout for attendance record
  static Future<bool> autoCompleteCheckout({
    required AttendanceModel attendance,
    required ShiftModel shift,
    String reason = 'Auto-completed by system',
  }) async {
    try {
      print('🔄 Auto-completing checkout for user ${attendance.userId}');
      
      // Calculate auto checkout time (shift end time or 30 minutes after shift end)
      final checkInDate = attendance.checkInTime!;
      final endTimeParts = shift.endTime.split(':');
      final endHour = int.parse(endTimeParts[0]);
      final endMinute = int.parse(endTimeParts[1]);
      
      final shiftEndTime = DateTime(
        checkInDate.year,
        checkInDate.month,
        checkInDate.day,
        endHour,
        endMinute,
      );
      
      // Add 30 minutes grace period for checkout
      final autoCheckoutTime = shiftEndTime.add(const Duration(minutes: 30));
      
      // Calculate total working minutes
      final totalMinutes = autoCheckoutTime.difference(attendance.checkInTime!).inMinutes;
      
      // Update the attendance record
      await FirebaseFirestore.instance
          .collection(_attendanceCollection)
          .doc(attendance.attendanceId)
          .update({
        'checkOutTime': Timestamp.fromDate(autoCheckoutTime),
        'totalMinutes': totalMinutes,
        'notes': '${attendance.notes ?? ''}\n$reason'.trim(),
      });
      
      print('✅ Auto-completed checkout at $autoCheckoutTime');
      return true;
    } catch (e) {
      print('❌ Error auto-completing checkout: $e');
      return false;
    }
  }
  
  /// Manual checkout completion by admin
  static Future<bool> manualCompleteCheckout({
    required AttendanceModel attendance,
    required DateTime checkoutTime,
    String reason = 'Manually completed by admin',
  }) async {
    try {
      print('🔄 Manually completing checkout for user ${attendance.userId}');
      
      // Calculate total working minutes
      final totalMinutes = checkoutTime.difference(attendance.checkInTime!).inMinutes;
      
      // Update the attendance record
      await FirebaseFirestore.instance
          .collection(_attendanceCollection)
          .doc(attendance.attendanceId)
          .update({
        'checkOutTime': Timestamp.fromDate(checkoutTime),
        'totalMinutes': totalMinutes,
        'notes': '${attendance.notes ?? ''}\n$reason'.trim(),
      });
      
      print('✅ Manually completed checkout at $checkoutTime');
      return true;
    } catch (e) {
      print('❌ Error manually completing checkout: $e');
      return false;
    }
  }
  
  /// Get incomplete checkout warning message for user
  static String getWarningMessage(AttendanceModel incompleteCheckout) {
    final checkInDate = incompleteCheckout.checkInTime!;
    final daysDifference = DateTime.now().difference(checkInDate).inDays;
    
    if (daysDifference == 0) {
      return 'You have not checked out today. Please complete your checkout.';
    } else if (daysDifference == 1) {
      return 'You forgot to check out yesterday. Your attendance needs completion.';
    } else {
      return 'You have an incomplete checkout from $daysDifference days ago. Please contact admin.';
    }
  }
  
  /// Get admin notification message
  static String getAdminNotification(List<AttendanceModel> incompleteCheckouts) {
    if (incompleteCheckouts.isEmpty) return '';
    
    final count = incompleteCheckouts.length;
    if (count == 1) {
      return '1 employee has an incomplete checkout that needs attention.';
    } else {
      return '$count employees have incomplete checkouts that need attention.';
    }
  }
  
  /// Check if attendance needs completion based on shift
  static bool needsCompletion(AttendanceModel attendance, ShiftModel shift) {
    if (attendance.hasCheckedOut) return false;
    if (!attendance.hasCheckedIn) return false;
    
    final checkInDate = attendance.checkInTime!;
    final endTimeParts = shift.endTime.split(':');
    final endHour = int.parse(endTimeParts[0]);
    final endMinute = int.parse(endTimeParts[1]);
    
    final shiftEndTime = DateTime(
      checkInDate.year,
      checkInDate.month,
      checkInDate.day,
      endHour,
      endMinute,
    );
    
    // If more than 2 hours have passed since shift end, it needs completion
    final now = DateTime.now();
    return now.isAfter(shiftEndTime.add(const Duration(hours: 2)));
  }
  
  /// Get suggested checkout time based on shift
  static DateTime getSuggestedCheckoutTime(AttendanceModel attendance, ShiftModel shift) {
    final checkInDate = attendance.checkInTime!;
    final endTimeParts = shift.endTime.split(':');
    final endHour = int.parse(endTimeParts[0]);
    final endMinute = int.parse(endTimeParts[1]);
    
    final shiftEndTime = DateTime(
      checkInDate.year,
      checkInDate.month,
      checkInDate.day,
      endHour,
      endMinute,
    );
    
    return shiftEndTime;
  }
}
