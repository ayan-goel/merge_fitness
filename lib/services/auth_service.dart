import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/goal_model.dart';
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
      
      // After successful login, check for workout reminders and initialize FCM
      if (!kIsWeb) {
        _checkWorkoutReminders();
      }
      
      // Initialize FCM token now that user is authenticated
      try {
        await notificationService.initializeFcmTokenAfterAuth();
      } catch (e) {
        print('Error initializing FCM after login: $e');
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
    // Clear FCM token before signing out
    try {
      await notificationService.clearFcmTokenOnLogout();
    } catch (e) {
      print('Error clearing FCM token on logout: $e');
      // Continue with logout even if FCM token clearing fails
    }
    
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
      
      // Set account status based on role
      if (role == UserRole.client) {
        userData['accountStatus'] = 'pending'; // New clients need approval
        // Note: trainerId will be assigned during approval process by super trainer
      } else {
        userData['accountStatus'] = 'approved'; // Trainers and admins are auto-approved
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
      // Get both regular trainers and super trainers
      final trainerQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .get();
          
      final superTrainerQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'superTrainer')
          .get();
          
      final trainerIds = trainerQuery.docs.map((doc) => doc.id).toList();
      final superTrainerIds = superTrainerQuery.docs.map((doc) => doc.id).toList();
      
      return [...trainerIds, ...superTrainerIds];
    } catch (e) {
      print("Error getting trainers: $e");
      return [];
    }
  }
  
  // Get all trainer user documents
  Future<List<UserModel>> getAllTrainers() async {
    try {
      // Get both regular trainers and super trainers
      final trainerQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .get();
          
      final superTrainerQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'superTrainer')
          .get();
      
      List<UserModel> trainers = [];
      
      // Process regular trainers
      for (var doc in trainerQuery.docs) {
        final data = doc.data();
        trainers.add(UserModel.fromMap(data, uid: doc.id, email: data['email'] ?? ''));
      }
      
      // Process super trainers
      for (var doc in superTrainerQuery.docs) {
        final data = doc.data();
        trainers.add(UserModel.fromMap(data, uid: doc.id, email: data['email'] ?? ''));
      }
      
      return trainers;
    } catch (e) {
      print("Error getting trainers: $e");
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
      case UserRole.superTrainer:
        return 'superTrainer';
      case UserRole.admin:
        return 'admin';
      case UserRole.client:
        return 'client';
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    double? height,
    double? weight,
    DateTime? dateOfBirth,
    List<Goal>? goals,
    String? phoneNumber,
    UserRole? role,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    // Update auth profile if needed
    if (firstName != null && lastName != null) {
      await user.updateDisplayName('$firstName $lastName');
    }
    
    // Update Firestore document
    Map<String, dynamic> data = {};
    
    if (firstName != null) data['firstName'] = firstName;
    if (lastName != null) data['lastName'] = lastName;
    if (firstName != null && lastName != null) data['displayName'] = '$firstName $lastName';
    if (height != null) data['height'] = height;
    if (weight != null) data['weight'] = weight;
    if (dateOfBirth != null) data['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
    if (goals != null) data['goals'] = goals.map((goal) => goal.toMap()).toList();
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

  // Check account status for current user
  Future<String> checkAccountStatus() async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['accountStatus'] ?? 'approved'; // Default to approved for existing users
      } else {
        return 'approved'; // Default for users without Firestore document
      }
    } catch (e) {
      print("Error checking account status: $e");
      return 'approved'; // Default on error
    }
  }

  // Get rejection reason for current user
  Future<String?> getRejectionReason() async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['rejectionReason'];
      } else {
        return null;
      }
    } catch (e) {
      print("Error getting rejection reason: $e");
      return null;
    }
  }

  // Update onboarding data for a user
  Future<void> updateOnboardingData(Map<String, dynamic> onboardingData) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'onboardingData': onboardingData,
      });
    } catch (e) {
      print("Error updating onboarding data: $e");
      throw e;
    }
  }

  // Reauthenticate user with password
  Future<bool> reauthenticateWithPassword(String password) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('No user is currently authenticated');
      }
      
      // Create credentials with current email and provided password
      AuthCredential credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      
      // Reauthenticate
      await currentUser.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      print('Reauthentication failed: ${e.code} - ${e.message}');
      if (e.code == 'wrong-password') {
        throw Exception('Incorrect password');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many failed attempts. Please try again later.');
      } else {
        throw Exception('Authentication failed: ${e.message}');
      }
    } catch (e) {
      print('Error during reauthentication: $e');
      throw Exception('Authentication failed: $e');
    }
  }

  // Delete user account and all associated data
  Future<void> deleteUserAccount(String userId) async {
    try {
      // CRITICAL: Verify that the current user is the one being deleted
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently authenticated');
      }
      
      if (currentUser.uid != userId) {
        throw Exception('Security violation: Cannot delete a different user account');
      }
      
      print('=== ACCOUNT DELETION START ===');
      print('Deleting account for user: $userId');
      print('Current authenticated user: ${currentUser.uid}');
      
      // Verify user document exists before deletion
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User document not found');
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      print('User role: ${userData['role']}');
      print('User email: ${userData['email']}');
      
      // Start individual deletions with explicit checks
      int deletedItems = 0;
      
      // 1. Delete weight history
      print('Deleting weight history...');
      QuerySnapshot weightHistory = await _firestore
          .collection('weightHistory')
          .where('userId', isEqualTo: userId)
          .get();
      print('Found ${weightHistory.docs.length} weight history entries');
      for (QueryDocumentSnapshot doc in weightHistory.docs) {
        await doc.reference.delete();
        deletedItems++;
      }
      
      // 2. Delete assigned workouts (as client)
      print('Deleting assigned workouts (as client)...');
      QuerySnapshot assignedWorkouts = await _firestore
          .collection('assignedWorkouts')
          .where('clientId', isEqualTo: userId)
          .get();
      print('Found ${assignedWorkouts.docs.length} assigned workouts');
      for (QueryDocumentSnapshot doc in assignedWorkouts.docs) {
        await doc.reference.delete();
        deletedItems++;
      }
      
      // 3. Delete workout progress
      print('Deleting workout progress...');
      QuerySnapshot workoutProgress = await _firestore
          .collection('workoutProgress')
          .where('clientId', isEqualTo: userId)
          .get();
      print('Found ${workoutProgress.docs.length} workout progress entries');
      for (QueryDocumentSnapshot doc in workoutProgress.docs) {
        await doc.reference.delete();
        deletedItems++;
      }
      
      // 4. Delete nutrition plans (as client)
      print('Deleting nutrition plans (as client)...');
      QuerySnapshot nutritionPlans = await _firestore
          .collection('nutritionPlans')
          .where('clientId', isEqualTo: userId)
          .get();
      print('Found ${nutritionPlans.docs.length} nutrition plans');
      for (QueryDocumentSnapshot doc in nutritionPlans.docs) {
        await doc.reference.delete();
        deletedItems++;
      }
      
      // 5. Delete session packages (as client)
      print('Deleting session packages (as client)...');
      QuerySnapshot sessionPackages = await _firestore
          .collection('sessionPackages')
          .where('clientId', isEqualTo: userId)
          .get();
      print('Found ${sessionPackages.docs.length} session packages');
      for (QueryDocumentSnapshot doc in sessionPackages.docs) {
        await doc.reference.delete();
        deletedItems++;
      }
      
      // 6. Delete onboarding forms
      print('Deleting onboarding forms...');
      QuerySnapshot onboardingForms = await _firestore
          .collection('onboardingForms')
          .where('userId', isEqualTo: userId)
          .get();
      print('Found ${onboardingForms.docs.length} onboarding forms');
      for (QueryDocumentSnapshot doc in onboardingForms.docs) {
        await doc.reference.delete();
        deletedItems++;
      }
      
      // 6a. Also check for onboarding forms with clientId field
      QuerySnapshot onboardingForms2 = await _firestore
          .collection('onboardingForms')
          .where('clientId', isEqualTo: userId)
          .get();
      print('Found ${onboardingForms2.docs.length} additional onboarding forms with clientId');
      for (QueryDocumentSnapshot doc in onboardingForms2.docs) {
        await doc.reference.delete();
        deletedItems++;
      }
      
      // 6b. Delete meals (if any)
      print('Deleting meals...');
      QuerySnapshot meals = await _firestore
          .collection('meals')
          .where('clientId', isEqualTo: userId)
          .get();
      print('Found ${meals.docs.length} meals');
      for (QueryDocumentSnapshot doc in meals.docs) {
        await doc.reference.delete();
        deletedItems++;
      }
      
      // 6c. Delete payment history (if any)
      print('Deleting payment history...');
      QuerySnapshot paymentHistory = await _firestore
          .collection('paymentHistory')
          .where('clientId', isEqualTo: userId)
          .get();
      print('Found ${paymentHistory.docs.length} payment history entries');
      for (QueryDocumentSnapshot doc in paymentHistory.docs) {
        await doc.reference.delete();
        deletedItems++;
      }
      
      // 7. IF USER IS A TRAINER: Delete workout templates they created
      if (userData['role'] == 'trainer' || userData['role'] == 'superTrainer') {
        print('User is a trainer, deleting workout templates...');
        QuerySnapshot workoutTemplates = await _firestore
            .collection('workoutTemplates')
            .where('trainerId', isEqualTo: userId)
            .get();
        print('Found ${workoutTemplates.docs.length} workout templates');
        for (QueryDocumentSnapshot doc in workoutTemplates.docs) {
          await doc.reference.delete();
          deletedItems++;
        }
        
        // Update any clients assigned to this trainer (remove trainer assignment)
        print('Updating clients assigned to this trainer...');
        QuerySnapshot assignedClients = await _firestore
            .collection('users')
            .where('trainerId', isEqualTo: userId)
            .get();
        print('Found ${assignedClients.docs.length} assigned clients');
        for (QueryDocumentSnapshot doc in assignedClients.docs) {
          await doc.reference.update({'trainerId': FieldValue.delete()});
          print('Removed trainer assignment from client: ${doc.id}');
        }
      }
      
      // 8. FINALLY: Delete the user document itself
      print('Deleting user document...');
      await _firestore.collection('users').doc(userId).delete();
      deletedItems++;
      
      print('Firestore data deletion completed. Total items deleted: $deletedItems');
      
      // 9. Delete the Firebase Auth user (must be last)
      print('Deleting Firebase Auth user...');
      await currentUser.delete();
      print('Firebase Auth user deleted successfully');
      
      print('=== ACCOUNT DELETION COMPLETE ===');
      
    } catch (e) {
      print('ERROR in deleteUserAccount: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Failed to delete account: $e');
    }
  }
} 