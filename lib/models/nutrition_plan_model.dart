import 'package:cloud_firestore/cloud_firestore.dart';

class NutritionPlan {
  final String id;
  final String clientId;
  final String trainerId;
  final String name;
  final String? description;
  final int dailyCalories;
  final Map<String, double> macronutrients; // protein, carbs, fat in grams
  final Map<String, double> micronutrients; // sodium, potassium, etc. in mg
  final DateTime assignedDate;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final List<String> mealSuggestions; // Optional meal suggestions

  NutritionPlan({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.name,
    this.description,
    required this.dailyCalories,
    required this.macronutrients,
    required this.micronutrients,
    required this.assignedDate,
    required this.startDate,
    this.endDate,
    this.notes,
    this.mealSuggestions = const [],
  });

  // Create from Firestore document
  factory NutritionPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle macronutrients
    Map<String, double> macros = {};
    if (data['macronutrients'] != null) {
      final macroData = data['macronutrients'] as Map<String, dynamic>;
      macroData.forEach((key, value) {
        macros[key] = (value is int) ? value.toDouble() : value;
      });
    } else {
      // Set defaults if not present
      macros = {
        'protein': 0.0,
        'carbs': 0.0,
        'fat': 0.0,
      };
    }
    
    // Handle micronutrients
    Map<String, double> micros = {};
    if (data['micronutrients'] != null) {
      final microData = data['micronutrients'] as Map<String, dynamic>;
      microData.forEach((key, value) {
        micros[key] = (value is int) ? value.toDouble() : value;
      });
    } else {
      // Set defaults if not present
      micros = {
        'sodium': 0.0,
        'potassium': 0.0,
        'calcium': 0.0,
        'iron': 0.0,
        'cholesterol': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
      };
    }
    
    // Handle meal suggestions
    List<String> suggestions = [];
    if (data['mealSuggestions'] != null) {
      suggestions = List<String>.from(data['mealSuggestions']);
    }
    
    return NutritionPlan(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      trainerId: data['trainerId'] ?? '',
      name: data['name'] ?? 'Nutrition Plan',
      description: data['description'],
      dailyCalories: data['dailyCalories'] ?? 0,
      macronutrients: macros,
      micronutrients: micros,
      assignedDate: (data['assignedDate'] as Timestamp).toDate(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      notes: data['notes'],
      mealSuggestions: suggestions,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'trainerId': trainerId,
      'name': name,
      'description': description,
      'dailyCalories': dailyCalories,
      'macronutrients': macronutrients,
      'micronutrients': micronutrients,
      'assignedDate': Timestamp.fromDate(assignedDate),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'notes': notes,
      'mealSuggestions': mealSuggestions,
    };
  }

  // Create a copy with optional updated fields
  NutritionPlan copyWith({
    String? id,
    String? clientId,
    String? trainerId,
    String? name,
    String? description,
    int? dailyCalories,
    Map<String, double>? macronutrients,
    Map<String, double>? micronutrients,
    DateTime? assignedDate,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    List<String>? mealSuggestions,
  }) {
    return NutritionPlan(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      trainerId: trainerId ?? this.trainerId,
      name: name ?? this.name,
      description: description ?? this.description,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      macronutrients: macronutrients ?? Map.from(this.macronutrients),
      micronutrients: micronutrients ?? Map.from(this.micronutrients),
      assignedDate: assignedDate ?? this.assignedDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      mealSuggestions: mealSuggestions ?? List.from(this.mealSuggestions),
    );
  }
} 