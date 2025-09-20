// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';

/// Initialize system settings if they don't exist
class SystemSettingsInitializer {
  static Future<void> initializeSystemSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('lock_status')
          .get();
      
      if (!doc.exists) {
        print('🔧 Creating initial system_settings document...');
        await FirebaseFirestore.instance
            .collection('system_settings')
            .doc('lock_status')
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
    }
  }
}
