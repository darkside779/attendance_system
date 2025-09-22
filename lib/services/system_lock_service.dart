// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

class SystemLockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _systemConfigDoc = 'system_config';
  static const String _systemCollection = 'system_settings';

  /// Check if system is locked
  Future<bool> isSystemLocked() async {
    try {
      final doc = await _firestore
          .collection(_systemCollection)
          .doc(_systemConfigDoc)
          .get();
      
      if (doc.exists) {
        return doc.data()?['isLocked'] ?? false;
      }
      return false;
    } catch (e) {
      // For now, assume system is unlocked if we can't check
      // This prevents the app from breaking due to Firebase rules
      return false;
    }
  }

  /// Lock the system (Super Admin only)
  Future<bool> lockSystem({
    required String superAdminId,
    String? reason,
  }) async {
    try {
      await _firestore
          .collection(_systemCollection)
          .doc(_systemConfigDoc)
          .set({
        'isLocked': true,
        'lockedBy': superAdminId,
        'lockReason': reason ?? 'System maintenance',
        'lockedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Unlock the system (Super Admin only)
  Future<bool> unlockSystem({
    required String superAdminId,
  }) async {
    try {
      await _firestore
          .collection(_systemCollection)
          .doc(_systemConfigDoc)
          .set({
        'isLocked': false,
        'unlockedBy': superAdminId,
        'unlockedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get system lock details
  Future<SystemLockInfo?> getSystemLockInfo() async {
    try {
      final doc = await _firestore
          .collection(_systemCollection)
          .doc(_systemConfigDoc)
          .get();
      
      if (doc.exists && doc.data() != null) {
        return SystemLockInfo.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stream system lock status for real-time updates
  Stream<bool> systemLockStatusStream() {
    return _firestore
        .collection(_systemCollection)
        .doc(_systemConfigDoc)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return doc.data()?['isLocked'] ?? false;
      }
      return false;
    });
  }
}

class SystemLockInfo {
  final bool isLocked;
  final String? lockedBy;
  final String? unlockedBy;
  final String? lockReason;
  final DateTime? lockedAt;
  final DateTime? unlockedAt;
  final DateTime? lastUpdated;

  SystemLockInfo({
    required this.isLocked,
    this.lockedBy,
    this.unlockedBy,
    this.lockReason,
    this.lockedAt,
    this.unlockedAt,
    this.lastUpdated,
  });

  factory SystemLockInfo.fromMap(Map<String, dynamic> map) {
    return SystemLockInfo(
      isLocked: map['isLocked'] ?? false,
      lockedBy: map['lockedBy'],
      unlockedBy: map['unlockedBy'],
      lockReason: map['lockReason'],
      lockedAt: (map['lockedAt'] as Timestamp?)?.toDate(),
      unlockedAt: (map['unlockedAt'] as Timestamp?)?.toDate(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }
}
