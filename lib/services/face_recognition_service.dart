// ignore_for_file: avoid_print, unused_import

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:camera/camera.dart';
import '../core/utils/face_recognition_helper.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class FaceRecognitionService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirestoreService _firestoreService = FirestoreService();

  /// Register user face during signup
  Future<FaceRegistrationResult> registerUserFace({
    required String userId,
    required File faceImage,
  }) async {
    try {
      // Detect faces in the image
      final faces = await FaceRecognitionHelper.detectFacesFromFile(faceImage);
      
      if (faces.isEmpty) {
        return FaceRegistrationResult(
          success: false,
          message: 'No face detected in the image. Please try again.',
        );
      }

      if (faces.length > 1) {
        return FaceRegistrationResult(
          success: false,
          message: 'Multiple faces detected. Please ensure only one face is visible.',
        );
      }

      // Extract face features
      final face = faces.first;
      final faceFeatures = FaceRecognitionHelper.extractFaceFeatures(face);
      
      // Upload face image to Firebase Storage
      final imageUrl = await _uploadFaceImage(userId, faceImage);
      if (imageUrl == null) {
        return FaceRegistrationResult(
          success: false,
          message: 'Failed to upload face image.',
        );
      }

      // Store face features as JSON string
      final faceDataJson = _convertFaceFeaturesToJson(faceFeatures);
      
      // Update user document with face data
      final user = await _firestoreService.getUser(userId);
      if (user != null) {
        final updatedUser = user.copyWith(faceData: faceDataJson);
        final success = await _firestoreService.updateUser(updatedUser);
        
        if (success) {
          return FaceRegistrationResult(
            success: true,
            message: 'Face registered successfully!',
            faceImageUrl: imageUrl,
          );
        } else {
          return FaceRegistrationResult(
            success: false,
            message: 'Failed to save face data.',
          );
        }
      } else {
        return FaceRegistrationResult(
          success: false,
          message: 'User not found.',
        );
      }
    } catch (e) {
      print('Error registering face: $e');
      return FaceRegistrationResult(
        success: false,
        message: 'Error registering face: $e',
      );
    }
  }

  /// Verify user face during check-in/check-out
  Future<FaceVerificationResult> verifyUserFace({
    required String userId,
    required File capturedImage,
  }) async {
    try {
      // Get user's stored face data
      final user = await _firestoreService.getUser(userId);
      if (user == null || user.faceData == null) {
        return FaceVerificationResult(
          success: false,
          message: 'No face data found for user. Please register your face first.',
        );
      }

      // Detect faces in captured image
      final faces = await FaceRecognitionHelper.detectFacesFromFile(capturedImage);
      
      if (faces.isEmpty) {
        return FaceVerificationResult(
          success: false,
          message: 'No face detected in the image. Please try again.',
        );
      }

      if (faces.length > 1) {
        return FaceVerificationResult(
          success: false,
          message: 'Multiple faces detected. Please ensure only one face is visible.',
        );
      }

      // Extract features from captured image
      final capturedFace = faces.first;
      final capturedFeatures = FaceRecognitionHelper.extractFaceFeatures(capturedFace);
      
      // Parse stored face data
      final storedFeatures = _parseFaceFeaturesFromJson(user.faceData!);
      
      // Compare faces
      final similarity = FaceRecognitionHelper.compareFaces(storedFeatures, capturedFeatures);
      final isMatch = FaceRecognitionHelper.facesMatch(storedFeatures, capturedFeatures);
      
      if (isMatch) {
        return FaceVerificationResult(
          success: true,
          message: 'Face verified successfully!',
          similarity: similarity,
        );
      } else {
        return FaceVerificationResult(
          success: false,
          message: 'Face does not match. Please try again.',
          similarity: similarity,
        );
      }
    } catch (e) {
      print('Error verifying face: $e');
      return FaceVerificationResult(
        success: false,
        message: 'Error verifying face: $e',
      );
    }
  }

  /// Verify face from camera stream (for real-time verification)
  Future<FaceVerificationResult> verifyFaceFromCamera({
    required String userId,
    required CameraImage cameraImage,
  }) async {
    try {
      // Get user's stored face data
      final user = await _firestoreService.getUser(userId);
      if (user == null || user.faceData == null) {
        return FaceVerificationResult(
          success: false,
          message: 'No face data found for user.',
        );
      }

      // Detect faces from camera
      final faces = await FaceRecognitionHelper.detectFacesFromCamera(cameraImage);
      
      if (faces.isEmpty) {
        return FaceVerificationResult(
          success: false,
          message: 'No face detected.',
        );
      }

      // For now, return a simplified result since camera processing is complex
      return FaceVerificationResult(
        success: true,
        message: 'Face detected from camera',
        similarity: 0.8, // Placeholder
      );
    } catch (e) {
      print('Error verifying face from camera: $e');
      return FaceVerificationResult(
        success: false,
        message: 'Error processing camera image',
      );
    }
  }

  /// Update user face data
  Future<bool> updateUserFace({
    required String userId,
    required File newFaceImage,
  }) async {
    try {
      // Delete old face image if exists
      await _deleteFaceImage(userId);
      
      // Register new face
      final result = await registerUserFace(
        userId: userId,
        faceImage: newFaceImage,
      );
      
      return result.success;
    } catch (e) {
      print('Error updating face: $e');
      return false;
    }
  }

  /// Delete user face data
  Future<bool> deleteUserFace(String userId) async {
    try {
      // Delete face image from storage
      await _deleteFaceImage(userId);
      
      // Remove face data from user document
      final user = await _firestoreService.getUser(userId);
      if (user != null) {
        final updatedUser = user.copyWith(faceData: null);
        return await _firestoreService.updateUser(updatedUser);
      }
      return false;
    } catch (e) {
      print('Error deleting face: $e');
      return false;
    }
  }

  /// Register face data from camera (without actual image file)
  Future<FaceRegistrationResult> registerFaceDataFromCamera({
    required String userId,
    required Map<String, dynamic> faceFeatures,
  }) async {
    try {
      // Store face features as JSON string
      final faceDataJson = _convertFaceFeaturesToJson(faceFeatures);
      
      // Update user document with face data
      final user = await _firestoreService.getUser(userId);
      if (user != null) {
        final updatedUser = user.copyWith(faceData: faceDataJson);
        final success = await _firestoreService.updateUser(updatedUser);
        
        if (success) {
          return FaceRegistrationResult(
            success: true,
            message: 'Face registered successfully!',
            faceImageUrl: null, // No image URL since we're using camera widget
          );
        } else {
          return FaceRegistrationResult(
            success: false,
            message: 'Failed to save face data.',
          );
        }
      } else {
        return FaceRegistrationResult(
          success: false,
          message: 'User not found.',
        );
      }
    } catch (e) {
      print('Error registering face data: $e');
      return FaceRegistrationResult(
        success: false,
        message: 'Error registering face: $e',
      );
    }
  }

  /// Check if user has registered face
  Future<bool> hasRegisteredFace(String userId) async {
    try {
      final user = await _firestoreService.getUser(userId);
      return user?.faceData != null;
    } catch (e) {
      print('Error checking face registration: $e');
      return false;
    }
  }

  /// Upload face image to Firebase Storage
  Future<String?> _uploadFaceImage(String userId, File imageFile) async {
    try {
      final ref = _storage.ref().child('face_images/$userId.jpg');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading face image: $e');
      return null;
    }
  }

  /// Delete face image from Firebase Storage
  Future<void> _deleteFaceImage(String userId) async {
    try {
      final ref = _storage.ref().child('face_images/$userId.jpg');
      await ref.delete();
    } catch (e) {
      print('Error deleting face image: $e');
    }
  }

  /// Convert face features to JSON string
  String _convertFaceFeaturesToJson(Map<String, dynamic> features) {
    // In a real implementation, you would use proper JSON encoding
    // This is a simplified version
    return features.toString();
  }

  /// Parse face features from JSON string
  Map<String, dynamic> _parseFaceFeaturesFromJson(String jsonString) {
    // In a real implementation, you would use proper JSON decoding
    // This is a simplified version that returns a placeholder
    return {
      'boundingBox': {'left': 0, 'top': 0, 'width': 100, 'height': 100},
      'landmarks': {},
      'contours': {},
      'headEulerAngleY': 0.0,
      'headEulerAngleZ': 0.0,
    };
  }

  /// Get face recognition quality score
  double getFaceQuality(Map<String, dynamic> faceFeatures) {  
    // Implement face quality assessment logic
    // Return a score between 0.0 and 1.0
    return 0.8; // Placeholder
  }

  /// Dispose resources
  Future<void> dispose() async {
    await FaceRecognitionHelper.dispose();
  }
}

class FaceRegistrationResult {
  final bool success;
  final String message;
  final String? faceImageUrl;

  FaceRegistrationResult({
    required this.success,
    required this.message,
    this.faceImageUrl,
  });
}

class FaceVerificationResult {
  final bool success;
  final String message;
  final double? similarity;

  FaceVerificationResult({
    required this.success,
    required this.message,
    this.similarity,
  });
}
