// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/settings_model.dart';

class SettingsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  SettingsModel? _currentSettings;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  SettingsModel? get currentSettings => _currentSettings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSettings => _currentSettings != null;
  LocationModel? get companyLocation => _currentSettings?.allowedLocation;

  /// Initialize and load settings
  Future<void> initialize() async {
    await loadSettings();
  }

  /// Load settings from Firestore
  Future<void> loadSettings() async {
    _setLoading(true);
    _clearError();

    try {
      final doc = await _firestore.collection('settings').doc('default').get();
      
      if (doc.exists) {
        _currentSettings = SettingsModel.fromJson(doc.data()!);
      } else {
        // Create default settings if none exist
        await createDefaultSettings();
        _currentSettings = SettingsModel(
          companyId: 'default',
          companyName: 'My Company',
          allowedLocation: LocationModel(
            latitude: 0.0,
            longitude: 0.0,
            radiusMeters: 100.0,
            address: 'Set your work location in settings',
          ),
          shifts: [
            ShiftModel(
              shiftId: 'default_shift',
              shiftName: 'Regular Shift',
              startTime: '09:00',
              endTime: '17:00',
              workingDays: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
              gracePeriodMinutes: 15,
              isActive: true,
            ),
          ],
          updatedAt: DateTime.now(),
        );
        await _firestore
            .collection('settings')
            .doc('default')
            .set(_currentSettings!.toJson());
      }
    } catch (e) {
      _setError('Failed to load settings: $e');
    }
    
    _setLoading(false);
  }

  /// Save settings to Firestore
  Future<bool> saveSettings(SettingsModel settings) async {
    _setLoading(true);
    _clearError();

    try {
      await _firestore.collection('settings').doc('default').set(settings.toJson());
      _currentSettings = settings;
      print('Settings saved successfully');
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to save settings: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Update company name
  Future<bool> updateCompanyName(String companyName) async {
    if (_currentSettings == null) return false;

    final updatedSettings = _currentSettings!.copyWith(
      companyName: companyName,
      updatedAt: DateTime.now(),
    );

    return await saveSettings(updatedSettings);
  }

  /// Update company location
  Future<bool> updateCompanyLocation(LocationModel location) async {
    if (_currentSettings == null) {
      // Create new settings if none exist
      final newSettings = SettingsModel(
        companyId: 'default',
        companyName: 'My Company',
        allowedLocation: location,
        shifts: [],
        updatedAt: DateTime.now(),
      );
      return await saveSettings(newSettings);
    }

    final updatedSettings = _currentSettings!.copyWith(
      allowedLocation: location,
      updatedAt: DateTime.now(),
    );

    return await saveSettings(updatedSettings);
  }

  /// Add or update shift
  Future<bool> updateShift(ShiftModel shift) async {
    if (_currentSettings == null) return false;

    final currentShifts = List<ShiftModel>.from(_currentSettings!.shifts);
    final existingIndex = currentShifts.indexWhere((s) => s.shiftId == shift.shiftId);

    if (existingIndex >= 0) {
      currentShifts[existingIndex] = shift;
    } else {
      currentShifts.add(shift);
    }

    final updatedSettings = _currentSettings!.copyWith(
      shifts: currentShifts,
      updatedAt: DateTime.now(),
    );

    return await saveSettings(updatedSettings);
  }

  /// Remove shift
  Future<bool> removeShift(String shiftId) async {
    if (_currentSettings == null) return false;

    final updatedShifts = _currentSettings!.shifts
        .where((shift) => shift.shiftId != shiftId)
        .toList();

    final updatedSettings = _currentSettings!.copyWith(
      shifts: updatedShifts,
      updatedAt: DateTime.now(),
    );

    return await saveSettings(updatedSettings);
  }

  /// Check if location is configured
  bool get isLocationConfigured {
    return _currentSettings?.allowedLocation != null &&
           _currentSettings!.allowedLocation.latitude != 0.0 &&
           _currentSettings!.allowedLocation.longitude != 0.0;
  }

  /// Get location configuration status message
  String get locationStatusMessage {
    if (!hasSettings) {
      return 'Settings not configured';
    }
    if (!isLocationConfigured) {
      return 'Work location not set';
    }
    return 'Location configured: ${_currentSettings!.allowedLocation.address}';
  }

  /// Reset settings (for testing purposes)
  Future<bool> resetSettings() async {
    _setLoading(true);
    _clearError();

    try {
      await _firestore.collection('settings').doc('default').delete();
      _currentSettings = null;
      print('Settings reset successfully');
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to reset settings: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Create default settings
  Future<bool> createDefaultSettings() async {
    final defaultSettings = SettingsModel(
      companyId: 'default',
      companyName: 'My Company',
      allowedLocation: LocationModel(
        latitude: 0.0,
        longitude: 0.0,
        radiusMeters: 100.0,
        address: 'Set your work location in settings',
      ),
      shifts: [
        ShiftModel(
          shiftId: 'default_shift',
          shiftName: 'Regular Shift',
          startTime: '09:00',
          endTime: '17:00',
          workingDays: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
          gracePeriodMinutes: 15,
          isActive: true,
        ),
      ],
      updatedAt: DateTime.now(),
    );

    return await saveSettings(defaultSettings);
  }

  /// Refresh settings from Firestore
  Future<void> refresh() async {
    await loadSettings();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
    print('SettingsProvider Error: $error');
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error manually
  void clearError() {
    _clearError();
  }


  // Get active shifts for a specific day
  List<ShiftModel> getActiveShiftsForDay(String dayName) {
    if (_currentSettings == null) return [];
    
    return _currentSettings!.shifts
        .where((shift) => shift.isActive && shift.workingDays.contains(dayName.toLowerCase()))
        .toList();
  }

  // Get shift by ID
  ShiftModel? getShiftById(String shiftId) {
    if (_currentSettings == null) return null;
    
    try {
      return _currentSettings!.shifts.firstWhere((shift) => shift.shiftId == shiftId);
    } catch (e) {
      return null;
    }
  }
}
