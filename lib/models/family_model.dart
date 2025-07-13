import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a family member
enum FamilyMemberStatus {
  pending,    // Invitation sent but not accepted yet
  active,     // Member is part of the family
  left,       // Member left the family
  removed,    // Member was removed by organizer
}

/// Represents a family member
class FamilyMember {
  final String userId;
  final String displayName;
  final String email;
  final String? photoUrl;
  final FamilyMemberStatus status;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final DateTime? invitedAt;
  final String? invitedBy; // userId of who invited them

  FamilyMember({
    required this.userId,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.status,
    required this.joinedAt,
    this.leftAt,
    this.invitedAt,
    this.invitedBy,
  });

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      status: _stringToFamilyMemberStatus(map['status'] ?? 'pending'),
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      leftAt: map['leftAt'] != null ? (map['leftAt'] as Timestamp).toDate() : null,
      invitedAt: map['invitedAt'] != null ? (map['invitedAt'] as Timestamp).toDate() : null,
      invitedBy: map['invitedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'status': _familyMemberStatusToString(status),
      'joinedAt': Timestamp.fromDate(joinedAt),
      'leftAt': leftAt != null ? Timestamp.fromDate(leftAt!) : null,
      'invitedAt': invitedAt != null ? Timestamp.fromDate(invitedAt!) : null,
      'invitedBy': invitedBy,
    };
  }

  // Helper to convert string to FamilyMemberStatus enum
  static FamilyMemberStatus _stringToFamilyMemberStatus(String statusStr) {
    switch (statusStr) {
      case 'pending':
        return FamilyMemberStatus.pending;
      case 'active':
        return FamilyMemberStatus.active;
      case 'left':
        return FamilyMemberStatus.left;
      case 'removed':
        return FamilyMemberStatus.removed;
      default:
        return FamilyMemberStatus.pending;
    }
  }

  // Helper to convert FamilyMemberStatus enum to string
  static String _familyMemberStatusToString(FamilyMemberStatus status) {
    switch (status) {
      case FamilyMemberStatus.pending:
        return 'pending';
      case FamilyMemberStatus.active:
        return 'active';
      case FamilyMemberStatus.left:
        return 'left';
      case FamilyMemberStatus.removed:
        return 'removed';
    }
  }

  // Create a copy with updated status
  FamilyMember copyWith({
    String? userId,
    String? displayName,
    String? email,
    String? photoUrl,
    FamilyMemberStatus? status,
    DateTime? joinedAt,
    DateTime? leftAt,
    DateTime? invitedAt,
    String? invitedBy,
  }) {
    return FamilyMember(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      invitedAt: invitedAt ?? this.invitedAt,
      invitedBy: invitedBy ?? this.invitedBy,
    );
  }

  // Check if member is currently active
  bool get isActive => status == FamilyMemberStatus.active;

  // Check if member has a pending invitation
  bool get isPending => status == FamilyMemberStatus.pending;
}

/// Represents a family unit
class Family {
  final String id;
  final String name;
  final String organizerId;
  final String organizerName;
  final String organizerEmail;
  final String? organizerPhotoUrl;
  final List<FamilyMember> members;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final String? description;

  Family({
    required this.id,
    required this.name,
    required this.organizerId,
    required this.organizerName,
    required this.organizerEmail,
    this.organizerPhotoUrl,
    required this.members,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.description,
  });

  factory Family.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Family(
      id: doc.id,
      name: data['name'] ?? '',
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      organizerEmail: data['organizerEmail'] ?? '',
      organizerPhotoUrl: data['organizerPhotoUrl'],
      members: (data['members'] as List<dynamic>?)
          ?.map((memberData) => FamilyMember.fromMap(memberData as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      isActive: data['isActive'] ?? true,
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'organizerEmail': organizerEmail,
      'organizerPhotoUrl': organizerPhotoUrl,
      'members': members.map((member) => member.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'description': description,
    };
  }

  // Get all active members (including organizer)
  List<FamilyMember> get activeMembers {
    return members.where((member) => member.isActive).toList();
  }

  // Get all pending invitations
  List<FamilyMember> get pendingInvitations {
    return members.where((member) => member.isPending).toList();
  }

  // Get total number of active members (including organizer)
  int get activeMemberCount {
    return activeMembers.length + 1; // +1 for organizer
  }

  // Check if a user is a member of this family
  bool isMember(String userId) {
    return userId == organizerId || members.any((member) => member.userId == userId && member.isActive);
  }

  // Check if a user is the organizer
  bool isOrganizer(String userId) {
    return userId == organizerId;
  }

  // Check if a user has a pending invitation
  bool hasPendingInvitation(String userId) {
    return members.any((member) => member.userId == userId && member.isPending);
  }

  // Get member by userId
  FamilyMember? getMember(String userId) {
    try {
      return members.firstWhere((member) => member.userId == userId);
    } catch (e) {
      return null;
    }
  }

  // Get all member user IDs (including organizer)
  List<String> get allMemberIds {
    final memberIds = activeMembers.map((member) => member.userId).toList();
    return [organizerId, ...memberIds];
  }

  // Get all member names (including organizer)
  List<String> get allMemberNames {
    final memberNames = activeMembers.map((member) => member.displayName).toList();
    return [organizerName, ...memberNames];
  }

  // Create a copy with updated data
  Family copyWith({
    String? id,
    String? name,
    String? organizerId,
    String? organizerName,
    String? organizerEmail,
    String? organizerPhotoUrl,
    List<FamilyMember>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? description,
  }) {
    return Family(
      id: id ?? this.id,
      name: name ?? this.name,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      organizerEmail: organizerEmail ?? this.organizerEmail,
      organizerPhotoUrl: organizerPhotoUrl ?? this.organizerPhotoUrl,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
    );
  }

  // Add a new member invitation
  Family addMemberInvitation(FamilyMember newMember) {
    final updatedMembers = [...members, newMember];
    return copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );
  }

  // Update member status
  Family updateMemberStatus(String userId, FamilyMemberStatus newStatus) {
    final updatedMembers = members.map((member) {
      if (member.userId == userId) {
        return member.copyWith(
          status: newStatus,
          leftAt: newStatus == FamilyMemberStatus.left ? DateTime.now() : null,
        );
      }
      return member;
    }).toList();
    
    return copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );
  }

  // Remove a member
  Family removeMember(String userId) {
    final updatedMembers = members.where((member) => member.userId != userId).toList();
    return copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );
  }
}

/// Represents a family invitation
class FamilyInvitation {
  final String id;
  final String familyId;
  final String familyName;
  final String organizerId;
  final String organizerName;
  final String invitedUserId;
  final String invitedUserEmail;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String status; // pending, accepted, declined, expired
  final String? message;

  FamilyInvitation({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.organizerId,
    required this.organizerName,
    required this.invitedUserId,
    required this.invitedUserEmail,
    required this.createdAt,
    this.respondedAt,
    required this.status,
    this.message,
  });

  factory FamilyInvitation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return FamilyInvitation(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      familyName: data['familyName'] ?? '',
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      invitedUserId: data['invitedUserId'] ?? '',
      invitedUserEmail: data['invitedUserEmail'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null ? (data['respondedAt'] as Timestamp).toDate() : null,
      status: data['status'] ?? 'pending',
      message: data['message'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'familyName': familyName,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'invitedUserId': invitedUserId,
      'invitedUserEmail': invitedUserEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'status': status,
      'message': message,
    };
  }

  // Check if invitation is still pending
  bool get isPending => status == 'pending';

  // Check if invitation has been accepted
  bool get isAccepted => status == 'accepted';

  // Check if invitation has been declined
  bool get isDeclined => status == 'declined';

  // Check if invitation has expired (older than 30 days)
  bool get isExpired {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    return createdAt.isBefore(thirtyDaysAgo);
  }
} 