import 'package:cloud_firestore/cloud_firestore.dart';
import 'goal_model.dart';

enum UserRole {
  client,
  trainer,
  superTrainer,
  admin,
}

enum AccountStatus {
  pending,
  approved,
  rejected,
}

class UserModel {
  final String uid;
  final String email;
  final UserRole role;
  final AccountStatus accountStatus;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? photoUrl;
  final double? height; // in cm
  final double? weight; // in kg
  final DateTime? dateOfBirth;
  final List<Goal>? goals;
  final String? phoneNumber;
  final String? trainerId; // ID of the trainer associated with this client
  final Map<String, dynamic>? onboardingData; // Store onboarding form data
  final String? rejectionReason; // Reason for rejection if account was rejected

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.accountStatus = AccountStatus.approved, // Default to approved for existing users
    this.firstName,
    this.lastName,
    this.displayName,
    this.photoUrl,
    this.height,
    this.weight,
    this.dateOfBirth,
    this.goals,
    this.phoneNumber,
    this.trainerId,
    this.onboardingData,
    this.rejectionReason,
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
          accountStatus: AccountStatus.approved, // Default for existing users
        );
      }
    } catch (e) {
      // Handle errors, default to client role
      return UserModel(
        uid: uid,
        email: email,
        role: UserRole.client,
        accountStatus: AccountStatus.approved, // Default for existing users
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
      accountStatus: _stringToAccountStatus(map['accountStatus'] ?? 'approved'),
      firstName: map['firstName'],
      lastName: map['lastName'],
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      height: map['height']?.toDouble(),
      weight: map['weight']?.toDouble(),
      dateOfBirth: map['dateOfBirth'] != null ? 
        (map['dateOfBirth'] as Timestamp).toDate() : null,
      goals: goalsData,
      phoneNumber: map['phoneNumber'],
      trainerId: map['trainerId'],
      onboardingData: map['onboardingData'] as Map<String, dynamic>?,
      rejectionReason: map['rejectionReason'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': _userRoleToString(role),
      'accountStatus': _accountStatusToString(accountStatus),
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'height': height,
      'weight': weight,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'goals': goals?.map((goal) => goal.toMap()).toList(),
      'phoneNumber': phoneNumber,
      'trainerId': trainerId,
      'onboardingData': onboardingData,
      'rejectionReason': rejectionReason,
    };
  }

  // Helper to convert string to UserRole enum
  static UserRole _stringToUserRole(String roleStr) {
    switch (roleStr) {
      case 'trainer':
        return UserRole.trainer;
      case 'superTrainer':
        return UserRole.superTrainer;
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
      case UserRole.superTrainer:
        return 'superTrainer';
      case UserRole.admin:
        return 'admin';
      case UserRole.client:
        return 'client';
    }
  }

  // Helper to convert string to AccountStatus enum
  static AccountStatus _stringToAccountStatus(String statusStr) {
    switch (statusStr) {
      case 'pending':
        return AccountStatus.pending;
      case 'rejected':
        return AccountStatus.rejected;
      case 'approved':
      default:
        return AccountStatus.approved;
    }
  }

  // Helper to convert AccountStatus enum to string
  static String _accountStatusToString(AccountStatus status) {
    switch (status) {
      case AccountStatus.pending:
        return 'pending';
      case AccountStatus.rejected:
        return 'rejected';
      case AccountStatus.approved:
        return 'approved';
    }
  }

  // Copy with method for immutability
  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? displayName,
    String? photoUrl,
    double? height,
    double? weight,
    DateTime? dateOfBirth,
    List<Goal>? goals,
    String? phoneNumber,
    UserRole? role,
    String? trainerId,
    AccountStatus? accountStatus,
    Map<String, dynamic>? onboardingData,
    String? rejectionReason,
  }) {
    return UserModel(
      uid: this.uid,
      email: this.email,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      goals: goals ?? this.goals,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      trainerId: trainerId ?? this.trainerId,
      onboardingData: onboardingData ?? this.onboardingData,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  // Helper methods for role checking
  bool get isTrainer => role == UserRole.trainer || role == UserRole.superTrainer;
  bool get isSuperTrainer => role == UserRole.superTrainer;
  bool get isClient => role == UserRole.client;
  bool get isAdmin => role == UserRole.admin;
  
  // Helper methods for account status checking
  bool get isPending => accountStatus == AccountStatus.pending;
  bool get isApproved => accountStatus == AccountStatus.approved;
  bool get isRejected => accountStatus == AccountStatus.rejected;
} 