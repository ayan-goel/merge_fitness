import 'package:cloud_firestore/cloud_firestore.dart';
import 'nutrition_plan_model.dart';

class NutritionPlanTemplate {
  final String? id;
  final String trainerId;
  final String name;
  final String? description;
  final int dailyCalories;
  final Map<String, double> macronutrients; // protein, carbs, fat in grams
  final Map<String, double> micronutrients; // sodium, potassium, etc. in mg
  final List<SampleMeal> sampleMeals;
  final List<String> mealSuggestions;
  final DateTime createdAt;
  final DateTime updatedAt;

  NutritionPlanTemplate({
    this.id,
    required this.trainerId,
    required this.name,
    this.description,
    required this.dailyCalories,
    required this.macronutrients,
    required this.micronutrients,
    this.sampleMeals = const [],
    this.mealSuggestions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Create from Firestore document
  factory NutritionPlanTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle macronutrients
    Map<String, double> macros = {};
    if (data['macronutrients'] != null) {
      final macroData = data['macronutrients'] as Map<String, dynamic>;
      macroData.forEach((key, value) {
        macros[key] = (value is int) ? value.toDouble() : value;
      });
    } else {
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
    
    // Handle sample meals
    List<SampleMeal> sampleMeals = [];
    if (data['sampleMeals'] != null) {
      final mealsData = data['sampleMeals'] as List<dynamic>;
      sampleMeals = mealsData.map((mealData) => SampleMeal.fromMap(mealData as Map<String, dynamic>)).toList();
    }
    
    return NutritionPlanTemplate(
      id: doc.id,
      trainerId: data['trainerId'] ?? '',
      name: data['name'] ?? 'Nutrition Plan Template',
      description: data['description'],
      dailyCalories: data['dailyCalories'] ?? 0,
      macronutrients: macros,
      micronutrients: micros,
      sampleMeals: sampleMeals,
      mealSuggestions: suggestions,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'trainerId': trainerId,
      'name': name,
      'description': description,
      'dailyCalories': dailyCalories,
      'macronutrients': macronutrients,
      'micronutrients': micronutrients,
      'mealSuggestions': mealSuggestions,
      'sampleMeals': sampleMeals.map((meal) => meal.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create a copy with optional updated fields
  NutritionPlanTemplate copyWith({
    String? id,
    String? trainerId,
    String? name,
    String? description,
    int? dailyCalories,
    Map<String, double>? macronutrients,
    Map<String, double>? micronutrients,
    List<SampleMeal>? sampleMeals,
    List<String>? mealSuggestions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NutritionPlanTemplate(
      id: id ?? this.id,
      trainerId: trainerId ?? this.trainerId,
      name: name ?? this.name,
      description: description ?? this.description,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      macronutrients: macronutrients ?? Map.from(this.macronutrients),
      micronutrients: micronutrients ?? Map.from(this.micronutrients),
      sampleMeals: sampleMeals ?? List.from(this.sampleMeals),
      mealSuggestions: mealSuggestions ?? List.from(this.mealSuggestions),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert template to NutritionPlan for a specific client
  NutritionPlan toNutritionPlan({
    required String clientId,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
  }) {
    return NutritionPlan(
      id: '', // Will be set by Firestore
      clientId: clientId,
      trainerId: trainerId,
      name: name,
      description: description,
      dailyCalories: dailyCalories,
      macronutrients: Map.from(macronutrients),
      micronutrients: Map.from(micronutrients),
      assignedDate: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      sampleMeals: List.from(sampleMeals),
      mealSuggestions: List.from(mealSuggestions),
    );
  }
}

