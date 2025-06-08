import 'package:cloud_firestore/cloud_firestore.dart';
import 'workout_template_model.dart';
import 'session_model.dart';

/// Status of an assigned workout
enum WorkoutStatus {
  assigned, // Workout has been assigned but not started
  inProgress, // Client has started but not completed the workout
  completed, // Client has completed the workout
  skipped, // Client has skipped the workout
}

/// Model representing a workout assigned to a client
class AssignedWorkout {
  final String id;
  final String trainerId;
  final String clientId;
  final String workoutTemplateId;
  final String workoutName;
  final String? workoutDescription;
  final DateTime scheduledDate;
  final WorkoutStatus status;
  final DateTime? completedDate;
  final String? feedback;
  final List<ExerciseTemplate> exercises;
  final String? notes;
  final bool isSessionBased; // New field to track if this is from a training session
  final String? sessionId; // Reference to the session if this is session-based

  AssignedWorkout({
    required this.id,
    required this.trainerId,
    required this.clientId,
    required this.workoutTemplateId,
    required this.workoutName,
    this.workoutDescription,
    required this.scheduledDate,
    required this.status,
    this.completedDate,
    this.feedback,
    required this.exercises,
    this.notes,
    this.isSessionBased = false, // Default to false for backwards compatibility
    this.sessionId,
  });

  factory AssignedWorkout.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return AssignedWorkout(
      id: doc.id,
      trainerId: data['trainerId'] ?? '',
      clientId: data['clientId'] ?? '',
      workoutTemplateId: data['workoutTemplateId'] ?? '',
      workoutName: data['workoutName'] ?? '',
      workoutDescription: data['workoutDescription'],
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      status: AssignedWorkout.workoutStatusFromString(data['status'] ?? 'assigned'),
      completedDate: data['completedDate'] != null 
        ? (data['completedDate'] as Timestamp).toDate() 
        : null,
      feedback: data['feedback'],
      exercises: (data['exercises'] as List<dynamic>?)
              ?.map((exerciseData) {
                final exerciseMap = exerciseData as Map<String, dynamic>;
                return ExerciseTemplate.fromMap(
                  exerciseMap, 
                  exerciseMap['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()
                );
              })
              .toList() ?? [],
      notes: data['notes'],
      isSessionBased: data['isSessionBased'] ?? false,
      sessionId: data['sessionId'],
    );
  }

  // Create an AssignedWorkout from a TrainingSession
  factory AssignedWorkout.fromSession(TrainingSession session) {
    WorkoutStatus status;
    DateTime? completedDate;
    
    switch (session.status) {
      case 'scheduled':
        // Check if session should be marked as completed (when current time is past the session end time)
        final now = DateTime.now();
        if (now.isAfter(session.endTime)) {
          status = WorkoutStatus.completed;
          completedDate = session.endTime;
        } else {
          status = WorkoutStatus.assigned;
        }
        break;
      case 'completed':
        status = WorkoutStatus.completed;
        completedDate = session.endTime;
        break;
      case 'cancelled':
        status = WorkoutStatus.skipped;
        break;
      default:
        status = WorkoutStatus.assigned;
    }
    
    // Format notes properly to avoid duplicate "Notes:" labels
    String formattedNotes = 'Training session at ${session.location}';
    
    if (session.notes != null && session.notes!.isNotEmpty) {
      // Check if the notes contain a cancellation reason
      if (session.notes!.contains('Cancellation reason:')) {
        // Split the notes to separate original notes from cancellation reason
        final parts = session.notes!.split('\n\nCancellation reason:');
        final originalNotes = parts[0].trim();
        final cancellationReason = parts.length > 1 ? parts[1].trim() : '';
        
        // Add original notes if they exist and are not just location info
        if (originalNotes.isNotEmpty && originalNotes != session.location) {
          formattedNotes += '\n\nNotes: $originalNotes';
        }
        
        // Add cancellation reason without extra "Notes:" prefix
        if (cancellationReason.isNotEmpty) {
          formattedNotes += '\n\nCancellation Reason: $cancellationReason';
        }
      } else {
        // No cancellation reason, just add regular notes
        formattedNotes += '\n\nNotes: ${session.notes}';
      }
    }

    return AssignedWorkout(
      id: 'session_${session.id}', // Prefix to distinguish from regular workouts
      trainerId: session.trainerId,
      clientId: session.clientId,
      workoutTemplateId: 'session_template',
      workoutName: 'Session with ${session.trainerName}',
      workoutDescription: 'Personal training session',
      scheduledDate: session.startTime,
      status: status,
      completedDate: completedDate,
      feedback: null,
      exercises: [], // Sessions don't have predefined exercises
      notes: formattedNotes,
      isSessionBased: true,
      sessionId: session.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trainerId': trainerId,
      'clientId': clientId,
      'workoutTemplateId': workoutTemplateId,
      'workoutName': workoutName,
      'workoutDescription': workoutDescription,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': AssignedWorkout.workoutStatusToString(status),
      'completedDate': completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'feedback': feedback,
      'exercises': exercises.map((exercise) => exercise.toMap()).toList(),
      'notes': notes,
      'isSessionBased': isSessionBased,
      'sessionId': sessionId,
    };
  }

  // Create a new assigned workout from a template
  factory AssignedWorkout.fromTemplate({
    required String clientId,
    required String workoutTemplateId,
    required WorkoutTemplate template,
    required DateTime scheduledDate,
    String? notes,
  }) {
    final now = DateTime.now();
    return AssignedWorkout(
      id: 'temp_${now.millisecondsSinceEpoch}',
      clientId: clientId,
      trainerId: template.trainerId,
      workoutTemplateId: workoutTemplateId,
      workoutName: template.name,
      workoutDescription: template.description,
      scheduledDate: scheduledDate,
      status: WorkoutStatus.assigned,
      exercises: template.exercises,
      notes: notes,
    );
  }

  AssignedWorkout copyWith({
    String? workoutName,
    String? workoutDescription,
    List<ExerciseTemplate>? exercises,
    DateTime? scheduledDate,
    DateTime? completedDate,
    WorkoutStatus? status,
    String? notes,
    String? feedback,
  }) {
    return AssignedWorkout(
      id: this.id,
      clientId: this.clientId,
      trainerId: this.trainerId,
      workoutTemplateId: this.workoutTemplateId,
      workoutName: workoutName ?? this.workoutName,
      workoutDescription: workoutDescription ?? this.workoutDescription,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      completedDate: completedDate ?? this.completedDate,
      feedback: feedback ?? this.feedback,
      exercises: exercises ?? this.exercises,
      notes: notes ?? this.notes,
      isSessionBased: this.isSessionBased,
      sessionId: this.sessionId,
    );
  }
  
  // Helper to convert string to WorkoutStatus enum
  static WorkoutStatus _stringToWorkoutStatus(String statusStr) {
    switch (statusStr) {
      case 'inProgress':
        return WorkoutStatus.inProgress;
      case 'completed':
        return WorkoutStatus.completed;
      case 'skipped':
        return WorkoutStatus.skipped;
      case 'assigned':
      default:
        return WorkoutStatus.assigned;
    }
  }

  // Helper to convert WorkoutStatus enum to string
  static String _workoutStatusToString(WorkoutStatus status) {
    switch (status) {
      case WorkoutStatus.inProgress:
        return 'inProgress';
      case WorkoutStatus.completed:
        return 'completed';
      case WorkoutStatus.skipped:
        return 'skipped';
      case WorkoutStatus.assigned:
        return 'assigned';
    }
  }
  
  // Public method to convert WorkoutStatus enum to string for external use
  static String workoutStatusToString(WorkoutStatus status) {
    return _workoutStatusToString(status);
  }
  
  // Public method to convert string to WorkoutStatus enum for external use
  static WorkoutStatus workoutStatusFromString(String statusStr) {
    return _stringToWorkoutStatus(statusStr);
  }
} 