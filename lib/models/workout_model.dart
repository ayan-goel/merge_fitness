import 'package:cloud_firestore/cloud_firestore.dart';

// Exercise details within a workout
class Exercise {
  final String name;
  final int sets;
  final int reps;
  final String? videoUrl;
  final String? imageUrl;
  final String? description;
  final List<String>? notes;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.videoUrl,
    this.imageUrl,
    this.description,
    this.notes,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      name: map['name'] ?? '',
      sets: map['sets'] ?? 0,
      reps: map['reps'] ?? 0,
      videoUrl: map['videoUrl'],
      imageUrl: map['imageUrl'],
      description: map['description'],
      notes: map['notes'] != null ? List<String>.from(map['notes']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'videoUrl': videoUrl,
      'imageUrl': imageUrl,
      'description': description,
      'notes': notes,
    };
  }
}

// Daily workout within a program
class WorkoutDay {
  final String day; // e.g., "Mon", "Tue", etc.
  final List<Exercise> exercises;
  final String? title;
  final String? description;

  WorkoutDay({
    required this.day,
    required this.exercises,
    this.title,
    this.description,
  });

  factory WorkoutDay.fromMap(Map<String, dynamic> map) {
    return WorkoutDay(
      day: map['day'] ?? '',
      exercises: map['exercises'] != null
          ? List<Exercise>.from(
              (map['exercises'] as List).map((e) => Exercise.fromMap(e)))
          : [],
      title: map['title'],
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'title': title,
      'description': description,
    };
  }
}

// Weekly workout program
class WorkoutProgram {
  final String id;
  final String trainerId;
  final String title;
  final String? description;
  final List<WorkoutDay> weeks;
  final DateTime createdAt;
  final DateTime? updatedAt;

  WorkoutProgram({
    required this.id,
    required this.trainerId,
    required this.title,
    this.description,
    required this.weeks,
    required this.createdAt,
    this.updatedAt,
  });

  factory WorkoutProgram.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return WorkoutProgram(
      id: doc.id,
      trainerId: data['trainerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      weeks: data['weeks'] != null
          ? List<WorkoutDay>.from(
              (data['weeks'] as List).map((w) => WorkoutDay.fromMap(w)))
          : [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'trainerId': trainerId,
      'title': title,
      'description': description,
      'weeks': weeks.map((w) => w.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

// Individual workout instance for a user
class WorkoutInstance {
  final String id;
  final String userId;
  final String programId;
  final DateTime date;
  final DateTime? completedAt;
  final List<String>? notes;

  WorkoutInstance({
    required this.id,
    required this.userId,
    required this.programId,
    required this.date,
    this.completedAt,
    this.notes,
  });

  factory WorkoutInstance.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return WorkoutInstance(
      id: doc.id,
      userId: data['userId'] ?? '',
      programId: data['programId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
      notes: data['notes'] != null ? List<String>.from(data['notes']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'programId': programId,
      'date': Timestamp.fromDate(date),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'notes': notes,
    };
  }

  // Mark workout as completed
  WorkoutInstance markAsCompleted() {
    return WorkoutInstance(
      id: id,
      userId: userId,
      programId: programId,
      date: date,
      completedAt: DateTime.now(),
      notes: notes,
    );
  }

  // Add a note to the workout
  WorkoutInstance addNote(String note) {
    List<String> updatedNotes = notes != null ? List<String>.from(notes!) : [];
    updatedNotes.add(note);
    
    return WorkoutInstance(
      id: id,
      userId: userId,
      programId: programId,
      date: date,
      completedAt: completedAt,
      notes: updatedNotes,
    );
  }
} 