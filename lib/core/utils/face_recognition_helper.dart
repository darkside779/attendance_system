// ignore_for_file: avoid_print

import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:camera/camera.dart';

class FaceRecognitionHelper {
  static final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector(
    FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
    ),
  );

  /// Detect faces in an image
  static Future<List<Face>> detectFaces(InputImage inputImage) async {
    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e) {
      print('Error detecting faces: $e');
      return [];
    }
  }

  /// Detect faces from camera image (simplified version)
  static Future<List<Face>> detectFacesFromCamera(CameraImage image) async {
    try {
      // For now, return empty list as this is a complex implementation
      // In production, you would properly convert CameraImage to InputImage
      // This is a placeholder for the actual ML Kit integration
      print('Face detection from camera not fully implemented yet');
      return [];
    } catch (e) {
      print('Error detecting faces from camera: $e');
      return [];
    }
  }

  /// Detect faces from file
  static Future<List<Face>> detectFacesFromFile(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      return await detectFaces(inputImage);
    } catch (e) {
      print('Error detecting faces from file: $e');
      return [];
    }
  }

  /// Extract face embeddings/features (simplified version)
  /// In a real implementation, you would use a more sophisticated ML model
  static Map<String, dynamic> extractFaceFeatures(Face face) {
    return {
      'boundingBox': {
        'left': face.boundingBox.left,
        'top': face.boundingBox.top,
        'width': face.boundingBox.width,
        'height': face.boundingBox.height,
      },
      'landmarks': face.landmarks.map((key, value) => MapEntry(
        key.toString(),
        {'x': value?.position.x, 'y': value?.position.y},
      )),
      'contours': face.contours.map((key, value) => MapEntry(
        key.toString(),
        value?.points.map((point) => {'x': point.x, 'y': point.y}).toList(),
      )),
      'headEulerAngleY': face.headEulerAngleY,
      'headEulerAngleZ': face.headEulerAngleZ,
    };
  }

  /// Compare two face features (simplified comparison)
  /// In a real implementation, you would use more sophisticated algorithms
  static double compareFaces(
    Map<String, dynamic> face1Features,
    Map<String, dynamic> face2Features,
  ) {
    try {
      // Simple comparison based on face landmarks
      // In production, use proper face recognition algorithms
      
      final face1Box = face1Features['boundingBox'];
      final face2Box = face2Features['boundingBox'];
      
      if (face1Box == null || face2Box == null) return 0.0;
      
      // Compare bounding box ratios
      final ratio1 = face1Box['width'] / face1Box['height'];
      final ratio2 = face2Box['width'] / face2Box['height'];
      
      final ratioSimilarity = 1.0 - (ratio1 - ratio2).abs();
      
      // Compare head angles
      final angle1Y = face1Features['headEulerAngleY'] ?? 0.0;
      final angle2Y = face2Features['headEulerAngleY'] ?? 0.0;
      final angle1Z = face1Features['headEulerAngleZ'] ?? 0.0;
      final angle2Z = face2Features['headEulerAngleZ'] ?? 0.0;
      
      final angleSimilarityY = 1.0 - (angle1Y - angle2Y).abs() / 180.0;
      final angleSimilarityZ = 1.0 - (angle1Z - angle2Z).abs() / 180.0;
      
      // Combined similarity score
      return (ratioSimilarity + angleSimilarityY + angleSimilarityZ) / 3.0;
    } catch (e) {
      print('Error comparing faces: $e');
      return 0.0;
    }
  }

  /// Check if faces match based on similarity threshold
  static bool facesMatch(
    Map<String, dynamic> face1Features,
    Map<String, dynamic> face2Features, {
    double threshold = 0.7,
  }) {
    final similarity = compareFaces(face1Features, face2Features);
    return similarity >= threshold;
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await _faceDetector.close();
    } catch (e) {
      // Handle web platform or other disposal errors gracefully
      print('Face detector disposal failed (likely web platform): $e');
    }
  }
}
