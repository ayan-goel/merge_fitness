import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_template_model.dart';
import '../models/assigned_workout_model.dart';

class WorkoutTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference get _templatesCollection => _firestore.collection('workoutTemplates');
  CollectionReference get _assignedWorkoutsCollection => _firestore.collection('assignedWorkouts');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Get all templates for a trainer
  Stream<List<WorkoutTemplate>> getTrainerTemplates(String trainerId) {
    return _templatesCollection
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => WorkoutTemplate.fromFirestore(doc))
              .toList();
        });
  }

  // Get a specific template
  Future<WorkoutTemplate?> getTemplate(String templateId) async {
    final doc = await _templatesCollection.doc(templateId).get();
    if (!doc.exists) return null;
    return WorkoutTemplate.fromFirestore(doc);
  }

  // Create a new template
  Future<WorkoutTemplate> createTemplate(WorkoutTemplate template) async {
    final docRef = await _templatesCollection.add(template.toMap());
    
    // Update the template with the new ID
    final newTemplate = WorkoutTemplate(
      id: docRef.id,
      trainerId: template.trainerId,
      name: template.name,
      description: template.description,
      exercises: template.exercises,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
    );
    
    // Update the document with the correct ID
    await docRef.update({'id': docRef.id});
    
    return newTemplate;
  }

  // Update an existing template
  Future<void> updateTemplate(WorkoutTemplate template) async {
    await _templatesCollection.doc(template.id).update(template.toMap());
  }

  // Delete a template
  Future<void> deleteTemplate(String templateId) async {
    await _templatesCollection.doc(templateId).delete();
  }

  // Assign a workout to a client
  Future<AssignedWorkout> assignWorkout(AssignedWorkout workout) async {
    final docRef = await _assignedWorkoutsCollection.add(workout.toMap());
    
    // Update the workout with the new ID
    final newWorkout = AssignedWorkout(
      id: docRef.id,
      clientId: workout.clientId,
      trainerId: workout.trainerId,
      workoutName: workout.workoutName,
      workoutDescription: workout.workoutDescription,
      exercises: workout.exercises,
      assignedDate: workout.assignedDate,
      scheduledDate: workout.scheduledDate,
      completedDate: workout.completedDate,
      status: workout.status,
      notes: workout.notes,
      feedback: workout.feedback,
    );
    
    // Update the document with the correct ID
    await docRef.update({'id': docRef.id});
    
    return newWorkout;
  }

  // Get all assigned workouts for a client
  Stream<List<AssignedWorkout>> getClientWorkouts(String clientId) {
    return _assignedWorkoutsCollection
        .where('clientId', isEqualTo: clientId)
        .orderBy('scheduledDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AssignedWorkout.fromFirestore(doc))
              .toList();
        });
  }

  // Get today's workout for a client
  Stream<List<AssignedWorkout>> getCurrentWorkouts(String clientId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    return _assignedWorkoutsCollection
        .where('clientId', isEqualTo: clientId)
        .where('scheduledDate', isGreaterThanOrEqualTo: startOfDay)
        .where('scheduledDate', isLessThanOrEqualTo: endOfDay)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AssignedWorkout.fromFirestore(doc))
              .toList();
        });
  }

  // Get workouts for a specific date range
  Stream<List<AssignedWorkout>> getWorkoutsInDateRange(String clientId, DateTime startDate, DateTime endDate) {
    return _assignedWorkoutsCollection
        .where('clientId', isEqualTo: clientId)
        .where('scheduledDate', isGreaterThanOrEqualTo: startDate)
        .where('scheduledDate', isLessThanOrEqualTo: endDate)
        .orderBy('scheduledDate')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AssignedWorkout.fromFirestore(doc))
              .toList();
        });
  }

  // Update an assigned workout status
  Future<void> updateWorkoutStatus(String workoutId, WorkoutStatus status, {String? feedback}) async {
    final Map<String, dynamic> data = {'status': AssignedWorkout.workoutStatusToString(status)};
    
    if (status == WorkoutStatus.completed) {
      data['completedDate'] = Timestamp.now();
    }
    
    if (feedback != null) {
      data['feedback'] = feedback;
    }
    
    await _assignedWorkoutsCollection.doc(workoutId).update(data);
  }

  // Get all clients for a trainer
  Future<List<Map<String, dynamic>>> getTrainerClients(String trainerId) async {
    final snapshot = await _usersCollection
        .where('role', isEqualTo: 'client')
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'displayName': data['displayName'] ?? 'Unknown',
        'email': data['email'] ?? '',
        'photoUrl': data['photoUrl'],
      };
    }).toList();
  }

  // Search for clients by name or email
  Future<List<Map<String, dynamic>>> searchClients(String trainerId, String query) async {
    final clients = await getTrainerClients(trainerId);
    
    if (query.isEmpty) {
      return clients;
    }
    
    final lowerQuery = query.toLowerCase();
    return clients.where((client) {
      final name = (client['displayName'] ?? '').toLowerCase();
      final email = (client['email'] ?? '').toLowerCase();
      return name.contains(lowerQuery) || email.contains(lowerQuery);
    }).toList();
  }

  // Get a specific assigned workout
  Future<AssignedWorkout?> getAssignedWorkout(String workoutId) async {
    final doc = await _assignedWorkoutsCollection.doc(workoutId).get();
    if (!doc.exists) return null;
    return AssignedWorkout.fromFirestore(doc);
  }

  // Delete an assigned workout
  Future<void> deleteAssignedWorkout(String workoutId) async {
    await _assignedWorkoutsCollection.doc(workoutId).delete();
  }
} 