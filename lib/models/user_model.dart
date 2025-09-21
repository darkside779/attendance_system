// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String name;
  final String email;
  final String role; // 'employee', 'admin', or 'superadmin'
  final String? faceData;
  final String position;
  final String? phoneNumber;
  final DateTime createdAt;
  final bool isActive;
  final String? assignedShiftId; // ID of the assigned shift

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.faceData,
    required this.position,
    this.phoneNumber,
    required this.createdAt,
    this.isActive = true,
    this.assignedShiftId,
  });

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'role': role,
      'faceData': faceData,
      'position': position,
      'phoneNumber': phoneNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'assignedShiftId': assignedShiftId,
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'employee',
      faceData: json['faceData'],
      position: json['position'] ?? '',
      phoneNumber: json['phoneNumber'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: json['isActive'] ?? true,
      assignedShiftId: json['assignedShiftId'],
    );
  }

  // Create UserModel from Firestore DocumentSnapshot
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }
    return UserModel.fromJson({...data, 'userId': doc.id});
  }

  // Copy with method for updating user data
  UserModel copyWith({
    String? userId,
    String? name,
    String? email,
    String? role,
    String? faceData,
    String? position,
    String? phoneNumber,
    DateTime? createdAt,
    bool? isActive,
    String? assignedShiftId,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      faceData: faceData ?? this.faceData,
      position: position ?? this.position,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      assignedShiftId: assignedShiftId ?? this.assignedShiftId,
    );
  }

  // Check if user is admin
  bool get isAdmin => role.toLowerCase() == 'admin';

  // Check if user is super admin
  bool get isSuperAdmin {
    final result = role.toLowerCase() == 'superadmin';
    print('🔍 UserModel.isSuperAdmin - Role: "$role", Result: $result');
    return result;
  }

  // Check if user is employee
  bool get isEmployee => role.toLowerCase() == 'employee';

  @override
  String toString() {
    return 'UserModel(userId: $userId, name: $name, email: $email, role: $role, position: $position, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;
}
