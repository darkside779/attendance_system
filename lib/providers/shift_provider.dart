// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift_model.dart';

class ShiftProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<ShiftModel> _shifts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ShiftModel> get shifts => _shifts;
  List<ShiftModel> get activeShifts => _shifts.where((shift) => shift.isActive).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasShifts => _shifts.isNotEmpty;

  /// Load all shifts from Firebase
  Future<void> loadShifts() async {
    _setLoading(true);
    _clearError();

    try {
      print('🔄 ShiftProvider: Loading shifts from Firebase');
      
      final doc = await _firestore.collection('settings').doc('default').get();
      
      if (doc.exists && doc.data()!.containsKey('shifts')) {
        final shiftsData = doc.data()!['shifts'] as List<dynamic>;
        
        _shifts = shiftsData.map((shiftData) => 
          ShiftModel.fromMap(Map<String, dynamic>.from(shiftData))
        ).toList();
        
        print('✅ ShiftProvider: Loaded ${_shifts.length} shifts');
        for (var shift in _shifts) {
          print('  - ${shift.shiftName}: ${shift.formattedShiftTime} (Active: ${shift.isActive})');
        }
      } else {
        print('❌ ShiftProvider: No shifts found in settings');
        _shifts = [];
      }
    } catch (e) {
      print('❌ ShiftProvider: Error loading shifts: $e');
      _errorMessage = 'Failed to load shift data: $e';
      _shifts = [];
    }

    _setLoading(false);
  }

  /// Get current active shift for a given time
  ShiftModel? getCurrentShift(DateTime dateTime) {
    final currentShifts = activeShifts.where((shift) => 
      shift.isWithinShiftWindow(dateTime)
    ).toList();
    
    if (currentShifts.isEmpty) return null;
    
    // If multiple shifts match, return the one with the earliest start time
    currentShifts.sort((a, b) => a.startTimeMinutes.compareTo(b.startTimeMinutes));
    return currentShifts.first;
  }

  /// Get shifts that allow check-in at current time
  List<ShiftModel> getAvailableShiftsForCheckIn(DateTime dateTime) {
    return activeShifts.where((shift) => 
      shift.canCheckIn(dateTime)
    ).toList();
  }

  /// Check if user can check in at current time
  bool canCheckInNow() {
    final now = DateTime.now();
    return getAvailableShiftsForCheckIn(now).isNotEmpty;
  }

  /// Get the next available check-in time
  DateTime? getNextCheckInTime() {
    final now = DateTime.now();
    final currentDay = now.weekday;
    
    // Check shifts for today
    for (var shift in activeShifts) {
      final dayName = _getDayName(currentDay);
      if (shift.workingDays.contains(dayName.toLowerCase())) {
        final checkInTime = DateTime(
          now.year,
          now.month,
          now.day,
          shift.startTimeMinutes ~/ 60,
          (shift.startTimeMinutes % 60) - shift.gracePeriodMinutes,
        );
        
        if (checkInTime.isAfter(now)) {
          return checkInTime;
        }
      }
    }
    
    // Check for next day
    final tomorrow = now.add(const Duration(days: 1));
    for (var shift in activeShifts) {
      final dayName = _getDayName(tomorrow.weekday);
      if (shift.workingDays.contains(dayName.toLowerCase())) {
        return DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          shift.startTimeMinutes ~/ 60,
          (shift.startTimeMinutes % 60) - shift.gracePeriodMinutes,
        );
      }
    }
    
    return null;
  }

  /// Get shift status message for UI
  String getShiftStatusMessage() {
    final now = DateTime.now();
    final currentShift = getCurrentShift(now);
    
    if (currentShift != null) {
      return 'Current shift: ${currentShift.shiftName} (${currentShift.formattedShiftTime})';
    }
    
    final availableShifts = getAvailableShiftsForCheckIn(now);
    if (availableShifts.isNotEmpty) {
      final shift = availableShifts.first;
      return 'Check-in available for: ${shift.shiftName} (${shift.formattedShiftTime})';
    }
    
    final nextCheckIn = getNextCheckInTime();
    if (nextCheckIn != null) {
      final formatter = _formatTime(nextCheckIn);
      return 'Next check-in available: $formatter';
    }
    
    return 'No shifts available for check-in';
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh shifts data
  Future<void> refresh() async {
    await loadShifts();
  }
}
