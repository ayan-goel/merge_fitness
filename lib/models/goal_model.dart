import 'package:cloud_firestore/cloud_firestore.dart';

class Goal {
  final String value;
  final bool completed;

  Goal({
    required this.value,
    this.completed = false,
  });

  // Create Goal from Firestore document
  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      value: map['value'] ?? '',
      completed: map['completed'] ?? false,
    );
  }

  // Create Goal from string (for backwards compatibility)
  factory Goal.fromString(String value) {
    return Goal(
      value: value,
      completed: false,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'completed': completed,
    };
  }

  // Copy with method for immutability
  Goal copyWith({
    String? value,
    bool? completed,
  }) {
    return Goal(
      value: value ?? this.value,
      completed: completed ?? this.completed,
    );
  }
} 