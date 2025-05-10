import 'package:cloud_firestore/cloud_firestore.dart';

class WeightEntry {
  final String id;
  final String userId;
  final double weight; // stored in kg in database
  final DateTime date;
  final double? bmi;
  final String? notes;

  WeightEntry({
    required this.id,
    required this.userId,
    required this.weight,
    required this.date,
    this.bmi,
    this.notes,
  });

  factory WeightEntry.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return WeightEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      weight: (data['weight'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      bmi: data['bmi']?.toDouble(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'weight': weight, // always stored in kg
      'date': Timestamp.fromDate(date),
      'bmi': bmi,
      'notes': notes,
    };
  }

  // Get weight in pounds
  double get weightInPounds {
    return weight * 2.20462;
  }

  // Create entry from pounds
  static WeightEntry fromPounds({
    required String id,
    required String userId,
    required double weightLbs,
    required DateTime date,
    double? bmi,
    String? notes,
  }) {
    // Convert pounds to kg for storage
    final weightKg = weightLbs / 2.20462;
    
    return WeightEntry(
      id: id,
      userId: userId,
      weight: weightKg, // Stored in kg
      date: date,
      bmi: bmi,
      notes: notes,
    );
  }

  // Calculate BMI using height (in cm) and weight (in kg)
  static double calculateBMI(double weightKg, double heightCm) {
    // Convert height to meters
    double heightM = heightCm / 100;
    // BMI = weight(kg) / height(m)²
    return weightKg / (heightM * heightM);
  }
  
  // Calculate BMI using height (in cm) and weight (in pounds)
  static double calculateBMIFromPounds(double weightLbs, double heightCm) {
    // Convert pounds to kg
    double weightKg = weightLbs / 2.20462;
    return calculateBMI(weightKg, heightCm);
  }
  
  // Convert kg to pounds
  static double kgToPounds(double kg) {
    return kg * 2.20462;
  }
  
  // Convert pounds to kg
  static double poundsToKg(double pounds) {
    return pounds / 2.20462;
  }
  
  // Get BMI category
  static String getBMICategory(double bmi) {
    if (bmi < 18.5) {
      return 'Underweight';
    } else if (bmi < 25) {
      return 'Normal weight';
    } else if (bmi < 30) {
      return 'Overweight';
    } else {
      return 'Obese';
    }
  }
} 