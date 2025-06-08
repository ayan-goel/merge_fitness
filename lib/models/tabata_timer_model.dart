import 'package:cloud_firestore/cloud_firestore.dart';

enum TabataPhase {
  exercise,
  rest,
  finished
}

enum TabataStatus {
  created,
  active,
  paused,
  finished
}

class TabataTimer {
  final String id;
  final String callId;
  final int exerciseTime; // seconds
  final int restTime; // seconds
  final int totalExercises;
  final int currentExercise;
  final TabataStatus status;
  final TabataPhase currentPhase;
  final int timeRemaining; // seconds
  final String createdBy;
  final String trainerId; // For Firestore permissions
  final String clientId; // For Firestore permissions
  final DateTime createdAt;
  final DateTime updatedAt;

  TabataTimer({
    required this.id,
    required this.callId,
    required this.exerciseTime,
    required this.restTime,
    required this.totalExercises,
    required this.currentExercise,
    required this.status,
    required this.currentPhase,
    required this.timeRemaining,
    required this.createdBy,
    required this.trainerId,
    required this.clientId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TabataTimer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return TabataTimer(
      id: doc.id,
      callId: data['callId'] ?? '',
      exerciseTime: data['exerciseTime'] ?? 45,
      restTime: data['restTime'] ?? 15,
      totalExercises: data['totalExercises'] ?? 8,
      currentExercise: data['currentExercise'] ?? 1,
      status: _parseStatus(data['status']),
      currentPhase: _parsePhase(data['currentPhase']),
      timeRemaining: data['timeRemaining'] ?? 45,
      createdBy: data['createdBy'] ?? '',
      trainerId: data['trainerId'] ?? '',
      clientId: data['clientId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'exerciseTime': exerciseTime,
      'restTime': restTime,
      'totalExercises': totalExercises,
      'currentExercise': currentExercise,
      'status': status.name,
      'currentPhase': currentPhase.name,
      'timeRemaining': timeRemaining,
      'createdBy': createdBy,
      'trainerId': trainerId,
      'clientId': clientId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static TabataStatus _parseStatus(String? status) {
    switch (status) {
      case 'created':
        return TabataStatus.created;
      case 'active':
        return TabataStatus.active;
      case 'paused':
        return TabataStatus.paused;
      case 'finished':
        return TabataStatus.finished;
      default:
        return TabataStatus.created;
    }
  }

  static TabataPhase _parsePhase(String? phase) {
    switch (phase) {
      case 'exercise':
        return TabataPhase.exercise;
      case 'rest':
        return TabataPhase.rest;
      case 'finished':
        return TabataPhase.finished;
      default:
        return TabataPhase.exercise;
    }
  }

  TabataTimer copyWith({
    String? id,
    String? callId,
    int? exerciseTime,
    int? restTime,
    int? totalExercises,
    int? currentExercise,
    TabataStatus? status,
    TabataPhase? currentPhase,
    int? timeRemaining,
    String? createdBy,
    String? trainerId,
    String? clientId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TabataTimer(
      id: id ?? this.id,
      callId: callId ?? this.callId,
      exerciseTime: exerciseTime ?? this.exerciseTime,
      restTime: restTime ?? this.restTime,
      totalExercises: totalExercises ?? this.totalExercises,
      currentExercise: currentExercise ?? this.currentExercise,
      status: status ?? this.status,
      currentPhase: currentPhase ?? this.currentPhase,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      createdBy: createdBy ?? this.createdBy,
      trainerId: trainerId ?? this.trainerId,
      clientId: clientId ?? this.clientId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == TabataStatus.active;
  bool get isPaused => status == TabataStatus.paused;
  bool get isFinished => status == TabataStatus.finished;
  bool get isCreated => status == TabataStatus.created;
  
  bool get isExercisePhase => currentPhase == TabataPhase.exercise;
  bool get isRestPhase => currentPhase == TabataPhase.rest;
  bool get isFinishedPhase => currentPhase == TabataPhase.finished;

  double get progress {
    if (isFinishedPhase) return 1.0;
    
    final totalTime = isExercisePhase ? exerciseTime : restTime;
    final elapsed = totalTime - timeRemaining;
    return elapsed / totalTime;
  }

  String get phaseDisplayName {
    switch (currentPhase) {
      case TabataPhase.exercise:
        return 'EXERCISE';
      case TabataPhase.rest:
        return 'REST';
      case TabataPhase.finished:
        return 'FINISHED';
    }
  }

  String get formattedTimeRemaining {
    final minutes = timeRemaining ~/ 60;
    final seconds = timeRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class TabataConfig {
  final int exerciseTime;
  final int restTime;
  final int totalExercises;

  TabataConfig({
    required this.exerciseTime,
    required this.restTime,
    required this.totalExercises,
  });

  Map<String, dynamic> toMap() {
    return {
      'exerciseTime': exerciseTime,
      'restTime': restTime,
      'totalExercises': totalExercises,
    };
  }

  int get totalDuration {
    return (exerciseTime + restTime) * totalExercises;
  }

  String get formattedTotalDuration {
    final minutes = totalDuration ~/ 60;
    final seconds = totalDuration % 60;
    return '${minutes}m ${seconds}s';
  }
} 