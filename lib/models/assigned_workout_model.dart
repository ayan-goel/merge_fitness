import 'package:cloud_firestore/cloud_firestore.dart';
import 'workout_template_model.dart';

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
  final String clientId;
  final String trainerId;
  final String workoutName;
  final String? workoutDescription;
  final List<ExerciseTemplate> exercises;
  final DateTime assignedDate;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final WorkoutStatus status;
  final String? notes;
  final String? feedback;

  AssignedWorkout({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.workoutName,
    this.workoutDescription,
    required this.exercises,
    required this.assignedDate,
    required this.scheduledDate,
    this.completedDate,
    required this.status,
    this.notes,
    this.feedback,
  });

  factory AssignedWorkout.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse exercises
    List<ExerciseTemplate> exercises = [];
    if (data['exercises'] != null) {
      for (var exercise in data['exercises']) {
        exercises.add(ExerciseTemplate.fromMap(
          exercise, 
          exercise['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()
        ));
      }
    }
    
    return AssignedWorkout(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      trainerId: data['trainerId'] ?? '',
      workoutName: data['workoutName'] ?? '',
      workoutDescription: data['workoutDescription'],
      exercises: exercises,
      assignedDate: (data['assignedDate'] as Timestamp).toDate(),
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      completedDate: data['completedDate'] != null 
        ? (data['completedDate'] as Timestamp).toDate() 
        : null,
      status: _stringToWorkoutStatus(data['status'] ?? 'assigned'),
      notes: data['notes'],
      feedback: data['feedback'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'trainerId': trainerId,
      'workoutName': workoutName,
      'workoutDescription': workoutDescription,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'assignedDate': Timestamp.fromDate(assignedDate),
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'completedDate': completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'status': _workoutStatusToString(status),
      'notes': notes,
      'feedback': feedback,
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
      workoutName: template.name,
      workoutDescription: template.description,
      exercises: template.exercises,
      assignedDate: now,
      scheduledDate: scheduledDate,
      status: WorkoutStatus.assigned,
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
      workoutName: workoutName ?? this.workoutName,
      workoutDescription: workoutDescription ?? this.workoutDescription,
      exercises: exercises ?? this.exercises,
      assignedDate: this.assignedDate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      feedback: feedback ?? this.feedback,
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
} 