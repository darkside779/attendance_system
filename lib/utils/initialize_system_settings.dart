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
        print('🔧 Creating initial system_settings document...');
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
        print('✅ System settings initialized successfully');
      } else {
        print('✅ System settings already exist');
      }
    } catch (e) {
      print('❌ Error initializing system settings: $e');
      // Don't throw error - system will work without this document
    }
  }
  
  /// Initialize system settings after user authentication
  static Future<void> initializeAfterAuth() async {
    // Only try to initialize if user is authenticated
    try {
      await initializeSystemSettings();
    } catch (e) {
      print('⚠️ Could not initialize system settings (user may not be authenticated): $e');
    }
  }
}
