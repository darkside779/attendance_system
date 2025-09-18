// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Get user data from Firestore
        final userData = await getUserData(result.user!.uid);
        return userData;
      }
      return null;
    } catch (e) {
      print('Error signing in: $e');
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String position,
    String role = 'employee',
    String? faceData,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Create user document in Firestore
        final userModel = UserModel(
          userId: result.user!.uid,
          name: name,
          email: email,
          role: role,
          position: position,
          faceData: faceData,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(userModel.toJson());

        return userModel;
      }
      return null;
    } catch (e) {
      print('Error registering: $e');
      throw _handleAuthException(e);
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user data
  Future<bool> updateUserData(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.userId)
          .update(user.toJson());
      return true;
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  // Update user face data
  Future<bool> updateUserFaceData(String userId, String faceData) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({'faceData': faceData});
      return true;
    } catch (e) {
      print('Error updating face data: $e');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      throw Exception('Failed to sign out');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error resetting password: $e');
      throw _handleAuthException(e);
    }
  }

  // Update email
  Future<bool> updateEmail(String newEmail) async {
    try {
      await currentUser?.verifyBeforeUpdateEmail(newEmail);
      return true;
    } catch (e) {
      print('Error updating email: $e');
      return false;
    }
  }

  // Update password
  Future<bool> updatePassword(String newPassword) async {
    try {
      await currentUser?.updatePassword(newPassword);
      return true;
    } catch (e) {
      print('Error updating password: $e');
      return false;
    }
  }

  // Delete user account
  Future<bool> deleteAccount() async {
    try {
      final userId = currentUser?.uid;
      if (userId != null) {
        // Delete user document from Firestore
        await _firestore.collection('users').doc(userId).delete();
        
        // Delete user account
        await currentUser?.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  // Check if user is admin
  Future<bool> isUserAdmin() async {
    final userId = currentUser?.uid;
    if (userId != null) {
      final userData = await getUserData(userId);
      return userData?.isAdmin ?? false;
    }
    return false;
  }

  // Get all employees (admin only)
  Future<List<UserModel>> getAllEmployees() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error getting employees: $e');
      return [];
    }
  }

  // Handle authentication exceptions
  String _handleAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'too-many-requests':
          return 'Too many requests. Try again later.';
        default:
          return e.message ?? 'An authentication error occurred.';
      }
    }
    return 'An unexpected error occurred.';
  }
}
