import 'package:cloud_firestore/cloud_firestore.dart';
import 'goal_model.dart';

enum UserRole {
  client,
  trainer,
  admin,
}

class UserModel {
  final String uid;
  final String email;
  final UserRole role;
  final String? displayName;
  final String? photoUrl;
  final double? height; // in cm
  final double? weight; // in kg
  final DateTime? dateOfBirth;
  final List<Goal>? goals;
  final String? phoneNumber;
  final String? trainerId; // ID of the trainer associated with this client

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
    this.photoUrl,
    this.height,
    this.weight,
    this.dateOfBirth,
    this.goals,
    this.phoneNumber,
    this.trainerId,
  });

  // Create user from Firebase User + Firestore data
  static Future<UserModel> fromFirebase({
    required String uid,
    required String email,
  }) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return UserModel.fromMap(data, uid: uid, email: email);
      } else {
        // Default to client role if document doesn't exist
        return UserModel(
          uid: uid,
          email: email,
          role: UserRole.client,
        );
      }
    } catch (e) {
      // Handle errors, default to client role
      return UserModel(
        uid: uid,
        email: email,
        role: UserRole.client,
      );
    }
  }

  // Create user from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map, {required String uid, required String email}) {
    // Handle both new Goal objects and legacy string goals
    List<Goal>? goalsData;
    if (map['goals'] != null) {
      // Check if the goals are already in the new format or still strings
      if (map['goals'] is List<dynamic> && map['goals'].isNotEmpty) {
        if (map['goals'].first is String) {
          // Convert string goals to Goal objects for backward compatibility
          goalsData = List<String>.from(map['goals']).map((g) => Goal.fromString(g)).toList();
        } else {
          // Goals are already in object format
          goalsData = List<Map<String, dynamic>>.from(map['goals'])
              .map((g) => Goal.fromMap(g))
              .toList();
        }
      }
    }
    
    return UserModel(
      uid: uid,
      email: email,
      role: _stringToUserRole(map['role'] ?? 'client'),
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      height: map['height']?.toDouble(),
      weight: map['weight']?.toDouble(),
      dateOfBirth: map['dateOfBirth'] != null ? 
        (map['dateOfBirth'] as Timestamp).toDate() : null,
      goals: goalsData,
      phoneNumber: map['phoneNumber'],
      trainerId: map['trainerId'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': _userRoleToString(role),
      'displayName': displayName,
      'photoUrl': photoUrl,
      'height': height,
      'weight': weight,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'goals': goals?.map((goal) => goal.toMap()).toList(),
      'phoneNumber': phoneNumber,
      'trainerId': trainerId,
    };
  }

  // Helper to convert string to UserRole enum
  static UserRole _stringToUserRole(String roleStr) {
    switch (roleStr) {
      case 'trainer':
        return UserRole.trainer;
      case 'admin':
        return UserRole.admin;
      case 'client':
      default:
        return UserRole.client;
    }
  }

  // Helper to convert UserRole enum to string
  static String _userRoleToString(UserRole role) {
    switch (role) {
      case UserRole.trainer:
        return 'trainer';
      case UserRole.admin:
        return 'admin';
      case UserRole.client:
        return 'client';
    }
  }

  // Copy with method for immutability
  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    double? height,
    double? weight,
    DateTime? dateOfBirth,
    List<Goal>? goals,
    String? phoneNumber,
    UserRole? role,
    String? trainerId,
  }) {
    return UserModel(
      uid: this.uid,
      email: this.email,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      goals: goals ?? this.goals,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      trainerId: trainerId ?? this.trainerId,
    );
  }
} 