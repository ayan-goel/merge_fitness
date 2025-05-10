import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_model.dart';
import 'firestore_service.dart';

class WorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if user is authenticated
  void _checkAuthentication() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
  }

  // Create a new workout program
  Future<String> createWorkoutProgram(WorkoutProgram program) async {
    _checkAuthentication();
    
    DocumentReference ref = await _firestore.collection('programs').add(
      program.toFirestore(),
    );
    
    return ref.id;
  }

  // Get a workout program by ID
  Future<WorkoutProgram?> getWorkoutProgram(String programId) async {
    DocumentSnapshot doc = await _firestore.collection('programs').doc(programId).get();
    
    if (doc.exists) {
      return WorkoutProgram.fromFirestore(doc);
    }
    
    return null;
  }

  // Update a workout program
  Future<void> updateWorkoutProgram(WorkoutProgram program) async {
    _checkAuthentication();
    
    await _firestore.collection('programs').doc(program.id).update(
      program.toFirestore(),
    );
  }

  // Delete a workout program
  Future<void> deleteWorkoutProgram(String programId) async {
    _checkAuthentication();
    
    await _firestore.collection('programs').doc(programId).delete();
  }

  // Get all workout programs for a trainer
  Future<List<WorkoutProgram>> getTrainerWorkoutPrograms() async {
    _checkAuthentication();
    
    QuerySnapshot snapshot = await _firestore
        .collection('programs')
        .where('trainerId', isEqualTo: currentUserId)
        .get();
    
    return snapshot.docs
        .map((doc) => WorkoutProgram.fromFirestore(doc))
        .toList();
  }

  // Get all workout programs for a client
  Future<List<WorkoutProgram>> getClientWorkoutPrograms() async {
    _checkAuthentication();
    
    // First get the workout instances assigned to the client
    QuerySnapshot instanceSnapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: currentUserId)
        .get();
    
    // Extract unique program IDs
    Set<String> programIds = {};
    for (var doc in instanceSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data['programId'] != null) {
        programIds.add(data['programId'] as String);
      }
    }
    
    if (programIds.isEmpty) {
      return [];
    }
    
    // Get the programs
    List<WorkoutProgram> programs = [];
    for (var id in programIds) {
      DocumentSnapshot programDoc = await _firestore.collection('programs').doc(id).get();
      if (programDoc.exists) {
        programs.add(WorkoutProgram.fromFirestore(programDoc));
      }
    }
    
    return programs;
  }

  // Create a workout instance for a user
  Future<String> createWorkoutInstance(WorkoutInstance instance) async {
    _checkAuthentication();
    
    DocumentReference ref = await _firestore.collection('workouts').add(
      instance.toFirestore(),
    );
    
    return ref.id;
  }

  // Get a workout instance by ID
  Future<WorkoutInstance?> getWorkoutInstance(String instanceId) async {
    DocumentSnapshot doc = await _firestore.collection('workouts').doc(instanceId).get();
    
    if (doc.exists) {
      return WorkoutInstance.fromFirestore(doc);
    }
    
    return null;
  }

  // Update a workout instance
  Future<void> updateWorkoutInstance(WorkoutInstance instance) async {
    _checkAuthentication();
    
    await _firestore.collection('workouts').doc(instance.id).update(
      instance.toFirestore(),
    );
  }

  // Mark a workout as completed
  Future<void> markWorkoutCompleted(String instanceId) async {
    _checkAuthentication();
    
    WorkoutInstance? instance = await getWorkoutInstance(instanceId);
    
    if (instance != null) {
      WorkoutInstance completedInstance = instance.markAsCompleted();
      await updateWorkoutInstance(completedInstance);
    }
  }

  // Add note to a workout
  Future<void> addWorkoutNote(String instanceId, String note) async {
    _checkAuthentication();
    
    WorkoutInstance? instance = await getWorkoutInstance(instanceId);
    
    if (instance != null) {
      WorkoutInstance updatedInstance = instance.addNote(note);
      await updateWorkoutInstance(updatedInstance);
    }
  }

  // Get user's workouts for a specific date
  Future<List<WorkoutInstance>> getWorkoutsForDate(DateTime date) async {
    _checkAuthentication();
    
    // Create date range to query for this day (start of day to end of day)
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    QuerySnapshot snapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: currentUserId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();
    
    return snapshot.docs
        .map((doc) => WorkoutInstance.fromFirestore(doc))
        .toList();
  }

  // Get user's upcoming workouts
  Future<List<WorkoutInstance>> getUpcomingWorkouts({int limit = 10}) async {
    _checkAuthentication();
    
    DateTime now = DateTime.now();
    
    QuerySnapshot snapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: currentUserId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('date')
        .limit(limit)
        .get();
    
    return snapshot.docs
        .map((doc) => WorkoutInstance.fromFirestore(doc))
        .toList();
  }

  // Get user's completed workouts
  Future<List<WorkoutInstance>> getCompletedWorkouts({int limit = 10}) async {
    _checkAuthentication();
    
    // Use a simpler query to avoid requiring a composite index
    // Get all workouts for the user, then filter client-side for completed ones
    QuerySnapshot snapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: currentUserId)
        .get();
    
    // Filter completed workouts client-side
    final workouts = snapshot.docs
        .map((doc) => WorkoutInstance.fromFirestore(doc))
        .where((workout) => workout.completedAt != null)
        .toList();
    
    // Sort by completedAt date (descending) client-side
    workouts.sort((a, b) {
      // Both workouts should have completedAt since we filtered above
      return b.completedAt!.compareTo(a.completedAt!);
    });
    
    // Apply limit if specified and if there are enough workouts
    if (limit > 0 && workouts.length > limit) {
      return workouts.sublist(0, limit);
    }
    
    return workouts;
  }

  // Stream user's workouts for today
  Stream<List<WorkoutInstance>> streamTodayWorkouts() {
    _checkAuthentication();
    
    // Create date range for today
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return _firestore
        .collection('workouts')
        .where('userId', isEqualTo: currentUserId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutInstance.fromFirestore(doc))
            .toList());
  }

  // Assign a workout program to a user for a specific date
  Future<String> assignWorkoutToUser({
    required String userId,
    required String programId,
    required DateTime date,
  }) async {
    _checkAuthentication();
    
    WorkoutInstance instance = WorkoutInstance(
      id: '', // Will be set by Firestore
      userId: userId,
      programId: programId,
      date: date,
    );
    
    return await createWorkoutInstance(instance);
  }
} 