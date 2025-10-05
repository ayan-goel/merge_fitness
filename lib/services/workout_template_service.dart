import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_template_model.dart';
import '../models/assigned_workout_model.dart';
import '../services/notification_service.dart';

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
  // Get all workout templates (shared across all trainers)
  Stream<List<WorkoutTemplate>> getTrainerTemplates(String trainerId) {
    // Note: trainerId parameter kept for backwards compatibility but not used
    // All trainers now have access to all workout templates
    return _templatesCollection
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
      workoutTemplateId: workout.workoutTemplateId,
      workoutName: workout.workoutName,
      workoutDescription: workout.workoutDescription,
      exercises: workout.exercises,
      scheduledDate: workout.scheduledDate,
      completedDate: workout.completedDate,
      status: workout.status,
      notes: workout.notes,
      feedback: workout.feedback,
      isSessionBased: workout.isSessionBased,
      sessionId: workout.sessionId,
      isRecurring: workout.isRecurring,
      recurringWeeks: workout.recurringWeeks,
      recurringDayOfWeek: workout.recurringDayOfWeek,
    );

    // Update the document with the correct ID
    await docRef.update({'id': docRef.id});

    return newWorkout;
  }

  // Assign multiple recurring workouts to a client
  Future<List<AssignedWorkout>> assignRecurringWorkouts(List<AssignedWorkout> workouts) async {
    final batch = _firestore.batch();
    final results = <AssignedWorkout>[];

    for (final workout in workouts) {
      final docRef = _assignedWorkoutsCollection.doc();
      batch.set(docRef, {
        ...workout.toMap(),
        'id': docRef.id,
      });

      results.add(AssignedWorkout(
        id: docRef.id,
        clientId: workout.clientId,
        trainerId: workout.trainerId,
        workoutTemplateId: workout.workoutTemplateId,
        workoutName: workout.workoutName,
        workoutDescription: workout.workoutDescription,
        scheduledDate: workout.scheduledDate,
        status: workout.status,
        completedDate: workout.completedDate,
        feedback: workout.feedback,
        exercises: workout.exercises,
        notes: workout.notes,
        isSessionBased: workout.isSessionBased,
        sessionId: workout.sessionId,
        isRecurring: workout.isRecurring,
        recurringWeeks: workout.recurringWeeks,
        recurringDayOfWeek: workout.recurringDayOfWeek,
      ));
    }

    await batch.commit();
    return results;
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
    
    // Get the workout details first to access client and trainer info
    final workoutDoc = await _assignedWorkoutsCollection.doc(workoutId).get();
    if (!workoutDoc.exists) {
      throw Exception('Workout not found');
    }
    
    final workout = AssignedWorkout.fromFirestore(workoutDoc);
    
    if (status == WorkoutStatus.completed) {
      data['completedDate'] = Timestamp.now();
      
      // Add to activity feed for the trainer
      try {
        // Get client name for the message
        final clientDoc = await _usersCollection.doc(workout.clientId).get();
        final clientData = clientDoc.data() as Map<String, dynamic>?;
        final clientName = clientDoc.exists && clientData != null 
            ? clientData['displayName'] ?? 'Client' 
            : 'Client';
        
        // Add activity to feed
        await FirebaseFirestore.instance.collection('activityFeed').add({
          'trainerId': workout.trainerId,
          'type': 'workout_completed',
          'message': '$clientName completed the workout "${workout.workoutName}"',
          'timestamp': FieldValue.serverTimestamp(),
          'relatedId': workoutId,
          'clientId': workout.clientId,
        });
        
        // Notification to trainer is now handled by Cloud Functions
      } catch (e) {
        print('Error adding workout completion to activity feed: $e');
        // Continue even if adding to activity feed fails
      }
    }
    
    if (feedback != null) {
      data['feedback'] = feedback;
    }
    
    await _assignedWorkoutsCollection.doc(workoutId).update(data);
  }

  // Get all clients for a trainer
  Future<List<Map<String, dynamic>>> getTrainerClients(String trainerId) async {
    // First, check if the current user is a super trainer
    final trainerDoc = await _usersCollection.doc(trainerId).get();
    final trainerData = trainerDoc.data() as Map<String, dynamic>?;
    final isSuperTrainer = trainerData?['role'] == 'superTrainer';
    
    if (isSuperTrainer) {
      // Super trainers can see all approved clients that have been assigned to a trainer
      final snapshot = await _usersCollection.where('role', isEqualTo: 'client').get();
      
      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Only show clients that are approved
        if (data['accountStatus'] != 'approved') {
          return false;
        }
        
        // Only show clients that have been assigned to a trainer
        final hasTrainerId = data['trainerId'] != null;
        final hasTrainerIds = data['trainerIds'] is List && (data['trainerIds'] as List).isNotEmpty;
        
        return hasTrainerId || hasTrainerIds;
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'displayName': data['displayName'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'photoUrl': data['photoUrl'],
          'trainerId': data['trainerId'], // Include trainerId for reference
          'trainerIds': data['trainerIds'], // Include trainerIds for multiple trainer support
        };
      }).toList();
    } else {
      // Regular trainers - need to check both legacy and new trainer assignments
      final snapshot = await _usersCollection.where('role', isEqualTo: 'client').get();
      
      // Filter clients that are assigned to this trainer AND are approved
      final assignedClients = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Only show clients that are approved
        if (data['accountStatus'] != 'approved') {
          return false;
        }
        
        // Check legacy trainerId field
        if (data['trainerId'] == trainerId) {
          return true;
        }
        
        // Check new trainerIds array
        if (data['trainerIds'] is List) {
          final trainerIds = List<String>.from(data['trainerIds']);
          return trainerIds.contains(trainerId);
        }
        
        return false;
      }).toList();
      
      return assignedClients.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'displayName': data['displayName'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'photoUrl': data['photoUrl'],
          'trainerId': data['trainerId'], // Include trainerId for reference
          'trainerIds': data['trainerIds'], // Include trainerIds for multiple trainer support
        };
      }).toList();
    }
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

  // Get detailed client information for trainers
  Future<Map<String, dynamic>> getClientDetails(String clientId) async {
    try {
      // Get client document
      final doc = await _usersCollection.doc(clientId).get();
      if (!doc.exists) {
        throw Exception('Client not found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      
      // Calculate BMI if height and weight are available
      double? bmi;
      if (data['height'] != null && data['weight'] != null) {
        // BMI = weight(kg) / (height(m) * height(m))
        final heightInMeters = data['height'] / 100; // convert cm to meters
        bmi = data['weight'] / (heightInMeters * heightInMeters);
        // Round to 1 decimal place
        bmi = double.parse(bmi!.toStringAsFixed(1));
      }
      
      // Get most recent weight history entry
      double? mostRecentWeight = data['weight'];
      try {
        final weightHistoryDoc = await _firestore.collection('weightHistory')
            .where('userId', isEqualTo: clientId)
            .orderBy('date', descending: true)
            .limit(1)
            .get();
        
        if (weightHistoryDoc.docs.isNotEmpty) {
          final mostRecentEntry = weightHistoryDoc.docs.first.data();
          mostRecentWeight = mostRecentEntry['weight'];
        }
      } catch (e) {
        print('Error loading weight history: $e');
        // Continue with the user's weight from their profile
      }
      
      // Convert height to feet/inches for display
      Map<String, dynamic>? heightImperial;
      if (data['height'] != null) {
        // 1 cm = 0.0328084 feet
        double totalFeet = data['height'] * 0.0328084;
        int feet = totalFeet.floor();
        int inches = ((totalFeet - feet) * 12).round();
        heightImperial = {
          'feet': feet,
          'inches': inches,
        };
      }
      
      // Convert weight to lbs for display
      double? weightLbs;
      if (mostRecentWeight != null) {
        // 1 kg = 2.20462 lbs
        weightLbs = mostRecentWeight * 2.20462;
        weightLbs = double.parse(weightLbs.toStringAsFixed(1)); // Round to 1 decimal place
      }
      
      return {
        'id': clientId,
        'displayName': data['displayName'] ?? 'Unknown',
        'email': data['email'] ?? '',
        'phoneNumber': data['phoneNumber'] ?? '',
        'trainerId': data['trainerId'], // Include trainerId field
        'trainerIds': data['trainerIds'], // Include trainerIds for multiple trainer support
        'height': data['height'], // in cm
        'heightImperial': heightImperial,
        'weight': data['weight'], // in kg
        'mostRecentWeight': mostRecentWeight, // in kg
        'weightLbs': weightLbs, // in lbs
        'dateOfBirth': data['dateOfBirth'],
        'goals': data['goals'] ?? [],
        'bmi': bmi,
      };
    } catch (e) {
      print('Error getting client details: $e');
      rethrow;
    }
  }
} 