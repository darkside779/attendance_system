import 'package:intl/intl.dart';

class TimeCalculator {
  /// Calculate working minutes between check-in and check-out
  static int calculateWorkingMinutes(DateTime checkIn, DateTime checkOut) {
    return checkOut.difference(checkIn).inMinutes;
  }

  /// Calculate working hours between check-in and check-out
  static double calculateWorkingHours(DateTime checkIn, DateTime checkOut) {
    return checkOut.difference(checkIn).inMinutes / 60.0;
  }

  /// Format minutes to hours and minutes string
  static String formatMinutesToHoursMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  /// Format duration to readable string
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  /// Check if time is late based on expected check-in time
  static bool isLate(DateTime checkIn, DateTime expectedCheckIn) {
    return checkIn.isAfter(expectedCheckIn);
  }

  /// Check if employee left early
  static bool isEarlyLeave(DateTime checkOut, DateTime expectedCheckOut) {
    return checkOut.isBefore(expectedCheckOut);
  }

  /// Get current date string in YYYY-MM-DD format
  static String getCurrentDateString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  /// Get formatted time string
  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Get formatted date string
  static String formatDate(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  /// Get formatted date and time string
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  /// Check if two dates are the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Get start of day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Calculate late minutes
  static int calculateLateMinutes(DateTime checkIn, DateTime expectedCheckIn) {
    if (checkIn.isAfter(expectedCheckIn)) {
      return checkIn.difference(expectedCheckIn).inMinutes;
    }
    return 0;
  }

  /// Calculate overtime minutes
  static int calculateOvertimeMinutes(DateTime checkOut, DateTime expectedCheckOut) {
    if (checkOut.isAfter(expectedCheckOut)) {
      return checkOut.difference(expectedCheckOut).inMinutes;
    }
    return 0;
  }
}
