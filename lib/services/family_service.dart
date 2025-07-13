import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/family_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  // Collection references
  CollectionReference get _familiesCollection => _firestore.collection('families');
  CollectionReference get _invitationsCollection => _firestore.collection('familyInvitations');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Create a new family
  Future<Family> createFamily({
    required String name,
    String? description,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Get current user data
    final user = await _authService.getUserModel();
    
    // Verify user can create a family
    if (!user.canCreateFamily) {
      throw Exception('User cannot create a family. Must be a client and not already in a family.');
    }

    final now = DateTime.now();
    
    // Create the family document
    final family = Family(
      id: '', // Will be set by Firestore
      name: name,
      organizerId: user.uid,
      organizerName: user.displayName ?? '${user.firstName} ${user.lastName}',
      organizerEmail: user.email,
      organizerPhotoUrl: user.photoUrl,
      members: [], // Start with empty members list
      createdAt: now,
      description: description,
    );

    // Add to Firestore
    final docRef = await _familiesCollection.add(family.toMap());
    
    // Update user document to include family information
    await _usersCollection.doc(user.uid).update({
      'familyId': docRef.id,
      'isFamilyOrganizer': true,
    });

    // Return the family with the correct ID
    return family.copyWith(id: docRef.id);
  }

  // Get family by ID
  Future<Family?> getFamily(String familyId) async {
    try {
      final doc = await _familiesCollection.doc(familyId).get();
      if (!doc.exists) {
        // If family doesn't exist but current user has a family reference, clean it up
        if (currentUserId != null) {
          final userDoc = await _usersCollection.doc(currentUserId!).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            if (userData['familyId'] == familyId) {
              // Clean up stale family reference
              await _usersCollection.doc(currentUserId!).update({
                'familyId': FieldValue.delete(),
                'isFamilyOrganizer': false,
              });
            }
          }
        }
        return null;
      }
      return Family.fromFirestore(doc);
    } catch (e) {
      print('Error getting family: $e');
      return null;
    }
  }

  // Get current user's family with proper membership validation
  Future<Family?> getCurrentUserFamily() async {
    if (currentUserId == null) return null;
    
    try {
      final user = await _authService.getUserModel();
      if (user.familyId == null) return null;
      
      final family = await getFamily(user.familyId!);
      if (family == null) return null;
      
      // CRITICAL: Verify the user is actually still a member of this family
      if (!family.isMember(currentUserId!)) {
        print('User is no longer a member of family ${family.id}, cleaning up stale family reference');
        
        // Clean up stale family reference
        await _usersCollection.doc(currentUserId!).update({
          'familyId': FieldValue.delete(),
          'isFamilyOrganizer': false,
        });
        
        return null;
      }
      
      return family;
    } catch (e) {
      print('Error getting current user family: $e');
      return null;
    }
  }

  // Search for other clients to invite
  Future<List<UserModel>> searchClientsForInvitation({
    required String query,
    required String familyId,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Trim and normalise query once here
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    try {
      final family = await getFamily(familyId);
      if (family == null) {
        throw Exception('Family not found');
      }

      // Verify current user is the organizer
      if (family.organizerId != currentUserId) {
        throw Exception('Only the family organizer can invite members');
      }

      // Use existing index: query all clients and filter in-memory
      final snapshot = await _usersCollection
          .where('role', isEqualTo: 'client')
          .get();

      final lowerQuery = trimmedQuery.toLowerCase();
      final List<UserModel> results = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final user = UserModel.fromMap(data, uid: doc.id, email: data['email']);

        // Filter out users who can't join families
        if (!user.canJoinFamily) continue;

        // Filter out users who are already in this family or have pending invitations
        if (family.isMember(user.uid) || family.hasPendingInvitation(user.uid)) continue;

        // Search in displayName, firstName, lastName, and email
        final displayName = (user.displayName ?? '').toLowerCase();
        final firstName = (user.firstName ?? '').toLowerCase();
        final lastName = (user.lastName ?? '').toLowerCase();
        final email = user.email.toLowerCase();

        if (displayName.contains(lowerQuery) || 
            firstName.contains(lowerQuery) || 
            lastName.contains(lowerQuery) || 
            email.contains(lowerQuery)) {
          results.add(user);
        }

        // Limit results to 10 to avoid overwhelming the UI
        if (results.length >= 10) break;
      }

      return results;
    } catch (e) {
      print('Error searching clients: $e');
      throw Exception('Failed to search clients: $e');
    }
  }

  // Invite a user to join the family
  Future<void> inviteUserToFamily({
    required String familyId,
    required String invitedUserId,
    String? message,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final family = await getFamily(familyId);
      if (family == null) {
        throw Exception('Family not found');
      }

      // Verify current user is the organizer
      if (family.organizerId != currentUserId) {
        throw Exception('Only the family organizer can invite members');
      }

      // Get invited user data
      final invitedUserDoc = await _usersCollection.doc(invitedUserId).get();
      if (!invitedUserDoc.exists) {
        throw Exception('User not found');
      }

      final invitedUserData = invitedUserDoc.data() as Map<String, dynamic>;
      final invitedUser = UserModel.fromMap(invitedUserData, uid: invitedUserId, email: invitedUserData['email']);

      // Verify the user can be invited
      if (!invitedUser.canJoinFamily) {
        throw Exception('User cannot join families');
      }

      // Check if user is already in the family or has a pending invitation
      if (family.isMember(invitedUserId) || family.hasPendingInvitation(invitedUserId)) {
        throw Exception('User is already in the family or has a pending invitation');
      }

      final now = DateTime.now();

      // Create family member with pending status
      final newMember = FamilyMember(
        userId: invitedUserId,
        displayName: invitedUser.displayName ?? '${invitedUser.firstName} ${invitedUser.lastName}',
        email: invitedUser.email,
        photoUrl: invitedUser.photoUrl,
        status: FamilyMemberStatus.pending,
        joinedAt: now,
        invitedAt: now,
        invitedBy: currentUserId,
      );

      // Update family document
      final updatedFamily = family.addMemberInvitation(newMember);
      await _familiesCollection.doc(familyId).update(updatedFamily.toMap());

      // Create invitation document
      final invitation = FamilyInvitation(
        id: '', // Will be set by Firestore
        familyId: familyId,
        familyName: family.name,
        organizerId: family.organizerId,
        organizerName: family.organizerName,
        invitedUserId: invitedUserId,
        invitedUserEmail: invitedUser.email,
        createdAt: now,
        status: 'pending',
        message: message,
      );

      await _invitationsCollection.add(invitation.toMap());

      // TODO: Send notification to invited user
      print('Invitation sent to ${invitedUser.email}');
    } catch (e) {
      print('Error inviting user: $e');
      throw Exception('Failed to invite user: $e');
    }
  }

  // Get pending invitations for current user
  Future<List<FamilyInvitation>> getPendingInvitations() async {
    if (currentUserId == null) return [];

    try {
      final query = await _invitationsCollection
          .where('invitedUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => FamilyInvitation.fromFirestore(doc))
          .where((invitation) => !invitation.isExpired)
          .toList();
    } catch (e) {
      print('Error getting pending invitations: $e');
      return [];
    }
  }

  // Accept family invitation
  Future<void> acceptInvitation(String invitationId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get invitation
      final invitationDoc = await _invitationsCollection.doc(invitationId).get();
      if (!invitationDoc.exists) {
        throw Exception('Invitation not found');
      }

      final invitation = FamilyInvitation.fromFirestore(invitationDoc);

      // Verify invitation is for current user and is pending
      if (invitation.invitedUserId != currentUserId) {
        throw Exception('Invalid invitation');
      }

      if (!invitation.isPending) {
        throw Exception('Invitation is no longer pending');
      }

      // Get family
      final family = await getFamily(invitation.familyId);
      if (family == null) {
        throw Exception('Family not found');
      }

      // Get current user data
      final user = await _authService.getUserModel();
      if (!user.canJoinFamily) {
        throw Exception('User cannot join families');
      }

      final now = DateTime.now();

      // Update invitation status
      await _invitationsCollection.doc(invitationId).update({
        'status': 'accepted',
        'respondedAt': Timestamp.fromDate(now),
      });

      // Update family member status to active
      final updatedFamily = family.updateMemberStatus(currentUserId!, FamilyMemberStatus.active);
      await _familiesCollection.doc(invitation.familyId).update(updatedFamily.toMap());

      // Update user document
      await _usersCollection.doc(currentUserId).update({
        'familyId': invitation.familyId,
        'isFamilyOrganizer': false,
      });

      print('Successfully joined family: ${family.name}');
    } catch (e) {
      print('Error accepting invitation: $e');
      throw Exception('Failed to accept invitation: $e');
    }
  }

  // Decline family invitation
  Future<void> declineInvitation(String invitationId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get invitation
      final invitationDoc = await _invitationsCollection.doc(invitationId).get();
      if (!invitationDoc.exists) {
        throw Exception('Invitation not found');
      }

      final invitation = FamilyInvitation.fromFirestore(invitationDoc);

      // Verify invitation is for current user and is pending
      if (invitation.invitedUserId != currentUserId) {
        throw Exception('Invalid invitation');
      }

      if (!invitation.isPending) {
        throw Exception('Invitation is no longer pending');
      }

      final now = DateTime.now();

      // Update invitation status
      await _invitationsCollection.doc(invitationId).update({
        'status': 'declined',
        'respondedAt': Timestamp.fromDate(now),
      });

      // Remove member from family
      final family = await getFamily(invitation.familyId);
      if (family != null) {
        final updatedFamily = family.removeMember(currentUserId!);
        await _familiesCollection.doc(invitation.familyId).update(updatedFamily.toMap());
      }

      print('Successfully declined invitation');
    } catch (e) {
      print('Error declining invitation: $e');
      throw Exception('Failed to decline invitation: $e');
    }
  }

  // Leave family (for non-organizers)
  Future<void> leaveFamily() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final user = await _authService.getUserModel();
      if (!user.isInFamily) {
        throw Exception('User is not in a family');
      }

      if (user.isFamilyOrganizer) {
        throw Exception('Organizers cannot leave the family. Use deleteFamily instead.');
      }

      final family = await getFamily(user.familyId!);
      if (family == null) {
        throw Exception('Family not found');
      }

      // Completely remove the member from the family
      final updatedFamily = family.removeMember(currentUserId!);
      await _familiesCollection.doc(user.familyId!).update(updatedFamily.toMap());

      // Update user document
      await _usersCollection.doc(currentUserId).update({
        'familyId': FieldValue.delete(),
        'isFamilyOrganizer': false,
      });

      print('Successfully left family');
    } catch (e) {
      print('Error leaving family: $e');
      throw Exception('Failed to leave family: $e');
    }
  }

  // Remove member from family (organizer only)
  Future<void> removeMemberFromFamily(String memberId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final user = await _authService.getUserModel();
      if (!user.isInFamily || !user.isFamilyOrganizer) {
        throw Exception('Only the family organizer can remove members');
      }

      final family = await getFamily(user.familyId!);
      if (family == null) {
        throw Exception('Family not found');
      }

      // Cannot remove the organizer
      if (memberId == family.organizerId) {
        throw Exception('Cannot remove the family organizer');
      }

      // Completely remove the member from the family
      final updatedFamily = family.removeMember(memberId);
      await _familiesCollection.doc(user.familyId!).update(updatedFamily.toMap());

      // Update removed member's user document
      await _usersCollection.doc(memberId).update({
        'familyId': FieldValue.delete(),
        'isFamilyOrganizer': false,
      });

      print('Successfully removed member from family');
    } catch (e) {
      print('Error removing member: $e');
      throw Exception('Failed to remove member: $e');
    }
  }

  // Delete family (organizer only)
  Future<void> deleteFamily() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final user = await _authService.getUserModel();
      if (!user.isInFamily || !user.isFamilyOrganizer) {
        throw Exception('Only the family organizer can delete the family');
      }

      final family = await getFamily(user.familyId!);
      if (family == null) {
        throw Exception('Family not found');
      }

      // Delete all pending invitations for this family
      final pendingInvitations = await _invitationsCollection
          .where('familyId', isEqualTo: user.familyId!)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingInvitations.docs) {
        await doc.reference.delete();
      }

      // Delete the family document
      await _familiesCollection.doc(user.familyId!).delete();

      // Update current user's document to remove family reference
      await _usersCollection.doc(currentUserId!).update({
        'familyId': FieldValue.delete(),
        'isFamilyOrganizer': false,
      });

      print('Successfully deleted family');
    } catch (e) {
      print('Error deleting family: $e');
      throw Exception('Failed to delete family: $e');
    }
  }

  // Update family information (organizer only)
  Future<void> updateFamily({
    required String familyId,
    String? name,
    String? description,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final family = await getFamily(familyId);
      if (family == null) {
        throw Exception('Family not found');
      }

      // Verify current user is the organizer
      if (family.organizerId != currentUserId) {
        throw Exception('Only the family organizer can update family information');
      }

      final Map<String, dynamic> updates = {
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;

      await _familiesCollection.doc(familyId).update(updates);
      print('Successfully updated family information');
    } catch (e) {
      print('Error updating family: $e');
      throw Exception('Failed to update family: $e');
    }
  }

  // Get family members with their user information
  Future<List<UserModel>> getFamilyMembers(String familyId) async {
    try {
      final family = await getFamily(familyId);
      if (family == null) return [];

      final List<UserModel> members = [];

      // Add organizer first
      final organizerDoc = await _usersCollection.doc(family.organizerId).get();
      if (organizerDoc.exists) {
        final userData = organizerDoc.data() as Map<String, dynamic>;
        members.add(UserModel.fromMap(userData, uid: organizerDoc.id, email: userData['email']));
      }

      // Add active members
      for (final member in family.activeMembers) {
        final memberDoc = await _usersCollection.doc(member.userId).get();
        if (memberDoc.exists) {
          final userData = memberDoc.data() as Map<String, dynamic>;
          members.add(UserModel.fromMap(userData, uid: memberDoc.id, email: userData['email']));
        }
      }

      return members;
    } catch (e) {
      print('Error getting family members: $e');
      return [];
    }
  }

  // Check if user can book for family members
  bool canBookForFamily(UserModel user, Family family) {
    // Only family members can book family sessions
    if (!family.isMember(user.uid)) return false;
    
    // All family members can book, but only organizer pays
    return true;
  }

  // Get family booking information for session booking
  Future<Map<String, dynamic>?> getFamilyBookingInfo(String? familyId) async {
    if (familyId == null) return null;

    try {
      final family = await getFamily(familyId);
      if (family == null) return null;

      final members = await getFamilyMembers(familyId);
      
      return {
        'family': family,
        'members': members,
        'organizerId': family.organizerId,
      };
    } catch (e) {
      print('Error getting family booking info: $e');
      return null;
    }
  }
} 