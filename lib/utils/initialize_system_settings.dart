// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';

/// Initialize system settings if they don't exist (only when authenticated)
class SystemSettingsInitializer {
  static Future<void> initializeSystemSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('system_config')
          .get();
      
      if (!doc.exists) {
        await FirebaseFirestore.instance
            .collection('system_settings')
            .doc('system_config')
            .set({
          'isLocked': false,
          'lockedBy': null,
          'lockReason': null,
          'lockedAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
      }
    } catch (e) {
      // Don't throw error - system will work without this document
    }
  }
  
  /// Initialize system settings after user authentication
  static Future<void> initializeAfterAuth() async {
    // Only try to initialize if user is authenticated
    try {
      await initializeSystemSettings();
    // ignore: empty_catches
    } catch (e) {
    }
  }
}
