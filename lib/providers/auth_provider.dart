// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isEmployee => _currentUser?.isEmployee ?? false;

  AuthProvider() {
    _initializeAuth();
  }

  /// Initialize authentication state
  void _initializeAuth() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  /// Load user data from Firestore
  Future<void> _loadUserData(String userId) async {
    try {
      final userData = await _authService.getUserData(userId);
      _currentUser = userData;
      notifyListeners();
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        _setLoading(false);
        return true;
      } else {
        _setError('Login failed. Please check your credentials.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Register new user
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String position,
    String role = 'employee',
    String? faceData,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        position: position,
        role: role,
        faceData: faceData,
      );

      if (user != null) {
        _currentUser = user;
        _setLoading(false);
        return true;
      } else {
        _setError('Registration failed. Please try again.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _setLoading(true);
    
    try {
      await _authService.signOut();
      _currentUser = null;
      _clearError();
    } catch (e) {
      _setError('Failed to sign out: $e');
    }
    
    _setLoading(false);
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.resetPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Check authentication state on app startup
  Future<void> checkAuthenticationState() async {
    _setLoading(true);
    
    try {
      final currentFirebaseUser = _authService.currentUser;
      if (currentFirebaseUser != null) {
        await _loadUserData(currentFirebaseUser.uid);
      } else {
        _currentUser = null;
      }
    } catch (e) {
      print('Error checking authentication state: $e');
      _currentUser = null;
    }
    
    _setLoading(false);
  }

  /// Update user data
  Future<bool> updateUser(UserModel updatedUser) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.updateUserData(updatedUser);
      if (success) {
        _currentUser = updatedUser;
        notifyListeners();
      } else {
        _setError('Failed to update user data');
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Update user face data
  Future<bool> updateFaceData(String faceData) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.updateUserFaceData(_currentUser!.userId, faceData);
      if (success) {
        _currentUser = _currentUser!.copyWith(faceData: faceData);
        notifyListeners();
      } else {
        _setError('Failed to update face data');
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Update email
  Future<bool> updateEmail(String newEmail) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.updateEmail(newEmail);
      if (success && _currentUser != null) {
        _currentUser = _currentUser!.copyWith(email: newEmail);
        notifyListeners();
      } else {
        _setError('Failed to update email');
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Update password
  Future<bool> updatePassword(String newPassword) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.updatePassword(newPassword);
      if (!success) {
        _setError('Failed to update password');
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Delete account
  Future<bool> deleteAccount() async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.deleteAccount();
      if (success) {
        _currentUser = null;
        notifyListeners();
      } else {
        _setError('Failed to delete account');
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Refresh user data
  Future<void> refreshUserData() async {
    if (_currentUser != null) {
      await _loadUserData(_currentUser!.userId);
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
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
}
