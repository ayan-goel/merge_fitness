import 'package:cloud_firestore/cloud_firestore.dart';

class BodyComposition {
  final String id;
  final String userId;
  final DateTime date;
  final double weight; // in kg
  final double? bodyFatPercentage;
  final double? leanMassKg;
  final String? notes;

  BodyComposition({
    required this.id,
    required this.userId,
    required this.date,
    required this.weight,
    this.bodyFatPercentage,
    this.leanMassKg,
    this.notes,
  });

  // Calculate lean mass if not provided but both weight and body fat percentage are available
  double? calculateLeanMass() {
    if (bodyFatPercentage != null) {
      return weight * (1 - bodyFatPercentage! / 100);
    }
    return null;
  }

  factory BodyComposition.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    double? leanMass = data['leanMassKg']?.toDouble();
    double weight = data['weight']?.toDouble() ?? 0.0;
    double? bodyFat = data['bodyFatPct']?.toDouble();
    
    // Calculate lean mass if not provided
    if (leanMass == null && bodyFat != null) {
      leanMass = weight * (1 - bodyFat / 100);
    }
    
    return BodyComposition(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      weight: weight,
      bodyFatPercentage: bodyFat,
      leanMassKg: leanMass,
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    // Calculate lean mass if not provided
    double? leanMass = leanMassKg ?? calculateLeanMass();
    
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'weight': weight,
      'bodyFatPct': bodyFatPercentage,
      'leanMassKg': leanMass,
      'notes': notes,
    };
  }

  // Create a copy with updated values
  BodyComposition copyWith({
    String? id,
    String? userId,
    DateTime? date,
    double? weight,
    double? bodyFatPercentage,
    double? leanMassKg,
    String? notes,
  }) {
    return BodyComposition(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      leanMassKg: leanMassKg ?? this.leanMassKg,
      notes: notes ?? this.notes,
    );
  }
} 