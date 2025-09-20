// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../models/shift_model.dart';
import '../utils/incomplete_checkout_helper.dart';

class IncompleteCheckoutProvider extends ChangeNotifier {
  List<AttendanceModel> _incompleteCheckouts = [];
  List<UserModel> _usersWithIncompleteCheckouts = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<AttendanceModel> get incompleteCheckouts => _incompleteCheckouts;
  List<UserModel> get usersWithIncompleteCheckouts => _usersWithIncompleteCheckouts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasIncompleteCheckouts => _incompleteCheckouts.isNotEmpty;
  int get incompleteCheckoutsCount => _incompleteCheckouts.length;
  
  /// Load all incomplete checkouts
  Future<void> loadIncompleteCheckouts() async {
    _setLoading(true);
    _clearError();
    
    try {
      print('🔄 Loading incomplete checkouts...');
      
      // Get incomplete checkouts from yesterday and before
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      _incompleteCheckouts = await IncompleteCheckoutHelper.findIncompleteCheckouts(
        beforeDate: yesterday,
      );
      
      // Get users with incomplete checkouts
      _usersWithIncompleteCheckouts = await IncompleteCheckoutHelper.getUsersForIncompleteCheckouts();
      
      print('✅ Loaded ${_incompleteCheckouts.length} incomplete checkouts');
      print('👥 Found ${_usersWithIncompleteCheckouts.length} users with incomplete checkouts');
      
    } catch (e) {
      print('❌ Error loading incomplete checkouts: $e');
      _setError('Failed to load incomplete checkouts: $e');
    }
    
    _setLoading(false);
  }
  
  /// Check if specific user has incomplete checkout
  Future<AttendanceModel?> checkUserIncompleteCheckout(String userId) async {
    try {
      return await IncompleteCheckoutHelper.getUserIncompleteCheckout(userId);
    } catch (e) {
      print('❌ Error checking user incomplete checkout: $e');
      return null;
    }
  }
  
  /// Auto-complete checkout for attendance record
  Future<bool> autoCompleteCheckout({
    required AttendanceModel attendance,
    required ShiftModel shift,
    String reason = 'Auto-completed by system',
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await IncompleteCheckoutHelper.autoCompleteCheckout(
        attendance: attendance,
        shift: shift,
        reason: reason,
      );
      
      if (success) {
        // Remove from incomplete list
        _incompleteCheckouts.removeWhere((a) => a.attendanceId == attendance.attendanceId);
        
        // Update users list
        final hasOtherIncomplete = _incompleteCheckouts.any((a) => a.userId == attendance.userId);
        if (!hasOtherIncomplete) {
          _usersWithIncompleteCheckouts.removeWhere((u) => u.userId == attendance.userId);
        }
        
        notifyListeners();
      } else {
        _setError('Failed to auto-complete checkout');
      }
      
      _setLoading(false);
      return success;
    } catch (e) {
      print('❌ Error auto-completing checkout: $e');
      _setError('Error auto-completing checkout: $e');
      _setLoading(false);
      return false;
    }
  }
  
  /// Manual checkout completion by admin
  Future<bool> manualCompleteCheckout({
    required AttendanceModel attendance,
    required DateTime checkoutTime,
    String reason = 'Manually completed by admin',
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await IncompleteCheckoutHelper.manualCompleteCheckout(
        attendance: attendance,
        checkoutTime: checkoutTime,
        reason: reason,
      );
      
      if (success) {
        // Remove from incomplete list
        _incompleteCheckouts.removeWhere((a) => a.attendanceId == attendance.attendanceId);
        
        // Update users list
        final hasOtherIncomplete = _incompleteCheckouts.any((a) => a.userId == attendance.userId);
        if (!hasOtherIncomplete) {
          _usersWithIncompleteCheckouts.removeWhere((u) => u.userId == attendance.userId);
        }
        
        notifyListeners();
      } else {
        _setError('Failed to manually complete checkout');
      }
      
      _setLoading(false);
      return success;
    } catch (e) {
      print('❌ Error manually completing checkout: $e');
      _setError('Error manually completing checkout: $e');
      _setLoading(false);
      return false;
    }
  }
  
  /// Get warning message for user
  String getUserWarningMessage(AttendanceModel incompleteCheckout) {
    return IncompleteCheckoutHelper.getWarningMessage(incompleteCheckout);
  }
  
  /// Get admin notification message
  String getAdminNotificationMessage() {
    return IncompleteCheckoutHelper.getAdminNotification(_incompleteCheckouts);
  }
  
  /// Check if attendance needs completion
  bool needsCompletion(AttendanceModel attendance, ShiftModel shift) {
    return IncompleteCheckoutHelper.needsCompletion(attendance, shift);
  }
  
  /// Get suggested checkout time
  DateTime getSuggestedCheckoutTime(AttendanceModel attendance, ShiftModel shift) {
    return IncompleteCheckoutHelper.getSuggestedCheckoutTime(attendance, shift);
  }
  
  /// Get incomplete checkouts for specific user
  List<AttendanceModel> getIncompleteCheckoutsForUser(String userId) {
    return _incompleteCheckouts.where((a) => a.userId == userId).toList();
  }
  
  /// Clear all data
  void clearData() {
    _incompleteCheckouts.clear();
    _usersWithIncompleteCheckouts.clear();
    _clearError();
    notifyListeners();
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
    notifyListeners();
  }
}
