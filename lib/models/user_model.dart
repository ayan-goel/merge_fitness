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
  final String? trainerId; // Legacy field - ID of the trainer associated with this client (for backwards compatibility)
  final List<String>? trainerIds; // New field - IDs of the trainers associated with this client
  final Map<String, dynamic>? onboardingData; // Store onboarding form data
  final String? rejectionReason; // Reason for rejection if account was rejected
  final String? familyId; // ID of the family this user belongs to
  final bool isFamilyOrganizer; // Whether this user is the organizer of their family

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
    this.trainerIds,
    this.onboardingData,
    this.rejectionReason,
    this.familyId,
    this.isFamilyOrganizer = false,
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
        // Document doesn't exist - throw error instead of defaulting to client
        print("WARNING: User document doesn't exist for uid: $uid");
        throw Exception('User document not found for uid: $uid');
      }
    } catch (e) {
      // Don't hide errors by defaulting to client role
      print("ERROR in UserModel.fromFirebase: $e");
      throw Exception('Failed to load user data: $e');
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
    
    // Handle trainer assignment backwards compatibility
    List<String>? trainerIds;
    String? trainerId = map['trainerId'];
    
    if (map['trainerIds'] != null) {
      // New format - use trainerIds array
      trainerIds = List<String>.from(map['trainerIds']);
    } else if (trainerId != null) {
      // Legacy format - convert single trainerId to array
      trainerIds = [trainerId];
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
      trainerId: trainerId,
      trainerIds: trainerIds,
      onboardingData: map['onboardingData'] as Map<String, dynamic>?,
      rejectionReason: map['rejectionReason'],
      familyId: map['familyId'],
      isFamilyOrganizer: map['isFamilyOrganizer'] ?? false,
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
      'trainerId': trainerId, // Keep for backwards compatibility
      'trainerIds': trainerIds,
      'onboardingData': onboardingData,
      'rejectionReason': rejectionReason,
      'familyId': familyId,
      'isFamilyOrganizer': isFamilyOrganizer,
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
    List<String>? trainerIds,
    AccountStatus? accountStatus,
    Map<String, dynamic>? onboardingData,
    String? rejectionReason,
    String? familyId,
    bool? isFamilyOrganizer,
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
      trainerIds: trainerIds ?? this.trainerIds,
      onboardingData: onboardingData ?? this.onboardingData,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      familyId: familyId ?? this.familyId,
      isFamilyOrganizer: isFamilyOrganizer ?? this.isFamilyOrganizer,
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
  
  // Helper methods for trainer assignments
  
  /// Get all assigned trainer IDs (supports both legacy and new format)
  List<String> get assignedTrainerIds {
    if (trainerIds != null && trainerIds!.isNotEmpty) {
      return trainerIds!;
    } else if (trainerId != null) {
      return [trainerId!];
    }
    return [];
  }
  
  /// Check if the client has any assigned trainers
  bool get hasAssignedTrainers => assignedTrainerIds.isNotEmpty;
  
  /// Check if the client has multiple assigned trainers
  bool get hasMultipleTrainers => assignedTrainerIds.length > 1;
  
  /// Get the primary trainer ID (first in the list, or the legacy trainerId)
  String? get primaryTrainerId {
    final ids = assignedTrainerIds;
    return ids.isNotEmpty ? ids.first : null;
  }
  
  /// Check if a specific trainer is assigned to this client
  bool isAssignedToTrainer(String trainerId) {
    return assignedTrainerIds.contains(trainerId);
  }
  
  /// Get a copy of this user with updated trainer assignments
  UserModel copyWithTrainers(List<String> newTrainerIds) {
    return copyWith(
      trainerIds: newTrainerIds,
      // Update legacy trainerId to first trainer for backwards compatibility
      trainerId: newTrainerIds.isNotEmpty ? newTrainerIds.first : null,
    );
  }

  // Helper methods for family membership
  
  /// Check if user is part of a family
  bool get isInFamily => familyId != null && familyId!.isNotEmpty;
  
  /// Check if user can create a family (clients only, not already in a family)
  bool get canCreateFamily => isClient && !isInFamily;
  
  /// Check if user can join a family (clients only, not already in a family)
  bool get canJoinFamily => isClient && !isInFamily;
  
  /// Get a copy of this user with updated family information
  UserModel copyWithFamily(String? newFamilyId, bool isOrganizer) {
    return copyWith(
      familyId: newFamilyId,
      isFamilyOrganizer: isOrganizer,
    );
  }
  
  /// Get a copy of this user with family removed
  UserModel copyWithoutFamily() {
    return copyWith(
      familyId: null,
      isFamilyOrganizer: false,
    );
  }
} 