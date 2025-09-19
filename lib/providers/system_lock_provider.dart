// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import '../services/system_lock_service.dart';

class SystemLockProvider extends ChangeNotifier {
  final SystemLockService _systemLockService = SystemLockService();
  
  bool _isSystemLocked = false;
  bool _isLoading = false;
  SystemLockInfo? _lockInfo;
  String? _errorMessage;

  // Getters
  bool get isSystemLocked => _isSystemLocked;
  bool get isLoading => _isLoading;
  SystemLockInfo? get lockInfo => _lockInfo;
  String? get errorMessage => _errorMessage;

  /// Initialize and listen to system lock status
  void initialize() {
    _listenToSystemLockStatus();
  }

  /// Listen to real-time system lock status changes
  void _listenToSystemLockStatus() {
    _systemLockService.systemLockStatusStream().listen(
      (isLocked) {
        _isSystemLocked = isLocked;
        if (isLocked) {
          _loadLockInfo();
        }
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Error monitoring system status: $error';
        notifyListeners();
      },
    );
  }

  /// Load system lock information
  Future<void> _loadLockInfo() async {
    try {
      _lockInfo = await _systemLockService.getSystemLockInfo();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading lock info: $e';
      notifyListeners();
    }
  }

  /// Check system lock status manually
  Future<void> checkSystemLockStatus() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Add a small delay to ensure authentication is complete
      await Future.delayed(const Duration(milliseconds: 500));
      _isSystemLocked = await _systemLockService.isSystemLocked();
      if (_isSystemLocked) {
        await _loadLockInfo();
      }
    } catch (e) {
      print('⚠️ SystemLockProvider: Error checking system status: $e');
      // Don't treat permission errors as fatal - assume system is unlocked
      if (e.toString().contains('permission-denied')) {
        print('⚠️ Permission denied - assuming system is unlocked for now');
        _isSystemLocked = false;
      } else {
        _errorMessage = 'Error checking system status: $e';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lock system (Super Admin only)
  Future<bool> lockSystem({
    required String superAdminId,
    String? reason,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _systemLockService.lockSystem(
        superAdminId: superAdminId,
        reason: reason,
      );

      if (success) {
        _isSystemLocked = true;
        await _loadLockInfo();
      } else {
        _errorMessage = 'Failed to lock system';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error locking system: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Unlock system (Super Admin only)
  Future<bool> unlockSystem({
    required String superAdminId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _systemLockService.unlockSystem(
        superAdminId: superAdminId,
      );

      if (success) {
        _isSystemLocked = false;
        await _loadLockInfo();
      } else {
        _errorMessage = 'Failed to unlock system';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error unlocking system: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
