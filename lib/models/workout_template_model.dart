import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a workout exercise with sets, reps, and media
class ExerciseTemplate {
  final String id;
  final String name;
  final String? description;
  final String? videoUrl;
  final String? videoId;
  final String? imageUrl;
  final int sets;
  final int reps;
  final int? restSeconds;
  final String? notes;
  final int? difficulty; // 1-5 scale, where 5 is most difficult

  ExerciseTemplate({
    required this.id,
    required this.name,
    this.description,
    this.videoUrl,
    this.videoId,
    this.imageUrl,
    required this.sets,
    required this.reps,
    this.restSeconds,
    this.notes,
    this.difficulty,
  });

  factory ExerciseTemplate.fromMap(Map<String, dynamic> map, String id) {
    return ExerciseTemplate(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      videoUrl: map['videoUrl'],
      videoId: map['videoId'],
      imageUrl: map['imageUrl'],
      sets: map['sets'] ?? 3,
      reps: map['reps'] ?? 10,
      restSeconds: map['restSeconds'],
      notes: map['notes'],
      difficulty: map['difficulty'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'videoUrl': videoUrl,
      'videoId': videoId,
      'imageUrl': imageUrl,
      'sets': sets,
      'reps': reps,
      'restSeconds': restSeconds,
      'notes': notes,
      'difficulty': difficulty,
    };
  }

  ExerciseTemplate copyWith({
    String? name,
    String? description,
    String? videoUrl,
    String? videoId,
    String? imageUrl,
    int? sets,
    int? reps,
    int? restSeconds,
    String? notes,
    int? difficulty,
  }) {
    return ExerciseTemplate(
      id: this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      videoId: videoId ?? this.videoId,
      imageUrl: imageUrl ?? this.imageUrl,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}

/// Model representing a reusable workout template
class WorkoutTemplate {
  final String id;
  final String trainerId;
  final String name;
  final String? description;
  final List<ExerciseTemplate> exercises;
  final String? fullWorkoutVideoId;
  final String? fullWorkoutVideoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutTemplate({
    required this.id,
    required this.trainerId,
    required this.name,
    this.description,
    required this.exercises,
    this.fullWorkoutVideoId,
    this.fullWorkoutVideoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutTemplate.fromFirestore(DocumentSnapshot doc) {
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
    
    return WorkoutTemplate(
      id: doc.id,
      trainerId: data['trainerId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      exercises: exercises,
      fullWorkoutVideoId: data['fullWorkoutVideoId'],
      fullWorkoutVideoUrl: data['fullWorkoutVideoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trainerId': trainerId,
      'name': name,
      'description': description,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'fullWorkoutVideoId': fullWorkoutVideoId,
      'fullWorkoutVideoUrl': fullWorkoutVideoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create a new template with default values
  factory WorkoutTemplate.create({
    required String trainerId,
    required String name,
    String? description,
  }) {
    final now = DateTime.now();
    return WorkoutTemplate(
      id: 'temp_${now.millisecondsSinceEpoch}',
      trainerId: trainerId,
      name: name,
      description: description,
      exercises: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  WorkoutTemplate copyWith({
    String? name,
    String? description,
    List<ExerciseTemplate>? exercises,
    String? fullWorkoutVideoId,
    String? fullWorkoutVideoUrl,
    DateTime? updatedAt,
  }) {
    return WorkoutTemplate(
      id: this.id,
      trainerId: this.trainerId,
      name: name ?? this.name,
      description: description ?? this.description,
      exercises: exercises ?? this.exercises,
      fullWorkoutVideoId: fullWorkoutVideoId ?? this.fullWorkoutVideoId,
      fullWorkoutVideoUrl: fullWorkoutVideoUrl ?? this.fullWorkoutVideoUrl,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is WorkoutTemplate && 
      other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
} 