import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../main.dart'; // For global notification service

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // After successful login, check for workout reminders
      if (!kIsWeb) {
        _checkWorkoutReminders();
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Auth error in signIn: ${e.code} - ${e.message}');
      // Don't convert the exception, just re-throw it
      throw e;
    }
  }

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword(
    String email, 
    String password, 
    {UserRole role = UserRole.client}
  ) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      try {
        await _createUserDocument(userCredential.user!, role: role);
        print("Firestore document created successfully");
      } catch (e) {
        print("Error creating Firestore document: $e");
        // Don't throw the error - we still want to return the userCredential
        // The user is created in Firebase Auth, even if Firestore fails
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Auth error in createUser: ${e.code} - ${e.message}');
      // Don't convert the exception, just re-throw it
      throw e;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Auth error in resetPassword: ${e.code} - ${e.message}');
      // Don't convert the exception, just re-throw it
      throw e;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(User user, {UserRole role = UserRole.client}) async {
    try {
      // Base user data
      Map<String, dynamic> userData = {
        'email': user.email,
        'role': _userRoleToString(role),
        'createdAt': Timestamp.now(),
      };
      
      // If this is a client, get and assign all trainer IDs
      if (role == UserRole.client) {
        List<String> trainerIds = await getAllTrainerIds();
        if (trainerIds.isNotEmpty) {
          // For now, just assign the first trainer
          // In a more advanced version, you could implement logic to distribute clients
          userData['trainerId'] = trainerIds.first;
        }
      }
      
      await _firestore.collection('users').doc(user.uid).set(userData);
    } catch (e) {
      print("Error in _createUserDocument: $e");
      throw e;
    }
  }

  // Get all trainers from Firestore
  Future<List<String>> getAllTrainerIds() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .get();
          
      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print("Error getting trainers: $e");
      return [];
    }
  }
  
  // Get all trainer user documents
  Future<List<UserModel>> getAllTrainers() async {
    try {
      final snapshot = await _firestore.collection('users')
          .where('role', isEqualTo: 'trainer')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return UserModel.fromMap(
          data,
          uid: doc.id,
          email: data['email'] ?? '',
        );
      }).toList();
    } catch (e) {
      print('Error getting trainers: $e');
      return [];
    }
  }

  // Get user model
  Future<UserModel> getUserModel() async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    return UserModel.fromFirebase(
      uid: user.uid,
      email: user.email!,
    );
  }

  // Helper to convert UserRole enum to string
  String _userRoleToString(UserRole role) {
    switch (role) {
      case UserRole.trainer:
        return 'trainer';
      case UserRole.admin:
        return 'admin';
      case UserRole.client:
        return 'client';
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
    double? height,
    double? weight,
    DateTime? dateOfBirth,
    List<String>? goals,
    String? phoneNumber,
    UserRole? role,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    // Update auth profile if needed
    if (displayName != null) {
      await user.updateDisplayName(displayName);
    }
    
    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }
    
    // Update Firestore document
    Map<String, dynamic> data = {};
    
    if (displayName != null) data['displayName'] = displayName;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (height != null) data['height'] = height;
    if (weight != null) data['weight'] = weight;
    if (dateOfBirth != null) data['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
    if (goals != null) data['goals'] = goals;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (role != null) data['role'] = _userRoleToString(role);
    
    if (data.isNotEmpty) {
      try {
        // Check if document exists first
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (doc.exists) {
          // Use update if the document exists
          await _firestore.collection('users').doc(user.uid).update(data);
        } else {
          // Use set if the document doesn't exist
          await _firestore.collection('users').doc(user.uid).set(data, SetOptions(merge: true));
        }
      } catch (e) {
        print("Error updating profile: $e");
        throw Exception('Failed to update profile: $e');
      }
    }
  }

  // Helper for creating user-friendly error messages (not used directly in the auth methods)
  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'Email is already in use. Please use a different email or try logging in.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'operation-not-allowed':
        return 'Operation not allowed.';
      case 'user-disabled':
        return 'User has been disabled.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  // Check workout reminders after login
  void _checkWorkoutReminders() async {
    try {
      // Get user document to check role
      User? user = _auth.currentUser;
      if (user == null) return;
      
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String role = userData['role'] ?? 'client';
      
      // Only setup reminders for clients
      if (role == 'client') {
        // Check for incomplete workouts immediately
        await notificationService.checkIncompleteWorkoutsAndNotify();
        
        // Also setup the daily reminder check routine
        await notificationService.setupDailyWorkoutReminderCheck();
      }
    } catch (e) {
      print('Error setting up workout reminders: $e');
    }
  }

  // Assign a trainer to a client (if not already assigned)
  Future<void> assignTrainerToClient(String clientId) async {
    try {
      // First check if client already has a trainer
      DocumentSnapshot clientDoc = await _firestore.collection('users').doc(clientId).get();
      
      if (!clientDoc.exists) {
        throw Exception('Client not found');
      }
      
      Map<String, dynamic> clientData = clientDoc.data() as Map<String, dynamic>;
      
      // Only assign if trainerId is missing or null
      if (clientData['trainerId'] == null) {
        List<String> trainerIds = await getAllTrainerIds();
        
        if (trainerIds.isEmpty) {
          print('No trainers available to assign');
          return;
        }
        
        // Assign the first available trainer
        await _firestore.collection('users').doc(clientId).update({
          'trainerId': trainerIds.first,
        });
        
        print('Assigned trainer ${trainerIds.first} to client $clientId');
      } else {
        print('Client already has a trainer assigned: ${clientData['trainerId']}');
      }
    } catch (e) {
      print('Error assigning trainer to client: $e');
      throw e;
    }
  }
} 