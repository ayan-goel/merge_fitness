import 'package:cloud_firestore/cloud_firestore.dart';

class MealEntry {
  final String id;
  final String clientId;
  final DateTime date;
  final String name;
  final String? description;
  final DateTime timeConsumed;
  final Map<String, double> macronutrients; // protein, carbs, fat
  final Map<String, double> micronutrients; // sodium, cholesterol, fiber, sugar
  final int calories;
  final String? imageUrl;
  final DateTime createdAt;

  MealEntry({
    required this.id,
    required this.clientId,
    required this.date,
    required this.name,
    this.description,
    required this.timeConsumed,
    required this.macronutrients,
    required this.micronutrients,
    required this.calories,
    this.imageUrl,
    required this.createdAt,
  });

  // Create an empty meal entry with default values
  factory MealEntry.empty(String clientId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return MealEntry(
      id: '',
      clientId: clientId,
      date: today,
      name: '',
      timeConsumed: now,
      macronutrients: {
        'protein': 0.0,
        'carbs': 0.0,
        'fat': 0.0,
      },
      micronutrients: {
        'sodium': 0.0,
        'cholesterol': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
      },
      calories: 0,
      createdAt: now,
    );
  }

  // Create from Firestore document
  factory MealEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MealEntry(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      name: data['name'] ?? '',
      description: data['description'],
      timeConsumed: (data['timeConsumed'] as Timestamp).toDate(),
      macronutrients: Map<String, double>.from(data['macronutrients'] ?? {}),
      micronutrients: Map<String, double>.from(data['micronutrients'] ?? {}),
      calories: data['calories'] ?? 0,
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'date': date,
      'name': name,
      'description': description,
      'timeConsumed': timeConsumed,
      'macronutrients': macronutrients,
      'micronutrients': micronutrients,
      'calories': calories,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
    };
  }

  // Create a copy with new values
  MealEntry copyWith({
    String? id,
    String? clientId,
    DateTime? date,
    String? name,
    String? description,
    DateTime? timeConsumed,
    Map<String, double>? macronutrients,
    Map<String, double>? micronutrients,
    int? calories,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return MealEntry(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      date: date ?? this.date,
      name: name ?? this.name,
      description: description ?? this.description,
      timeConsumed: timeConsumed ?? this.timeConsumed,
      macronutrients: macronutrients ?? this.macronutrients,
      micronutrients: micronutrients ?? this.micronutrients,
      calories: calories ?? this.calories,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DailyNutritionSummary {
  final DateTime date;
  final String clientId;
  final int totalCalories;
  final Map<String, double> totalMacronutrients;
  final Map<String, double> totalMicronutrients;
  final List<MealEntry> meals;

  DailyNutritionSummary({
    required this.date,
    required this.clientId,
    required this.totalCalories,
    required this.totalMacronutrients,
    required this.totalMicronutrients,
    required this.meals,
  });

  // Factory method to create a summary from a list of meals
  factory DailyNutritionSummary.fromMeals(List<MealEntry> meals, DateTime date, String clientId) {
    if (meals.isEmpty) {
      return DailyNutritionSummary(
        date: date,
        clientId: clientId,
        totalCalories: 0,
        totalMacronutrients: {
          'protein': 0.0,
          'carbs': 0.0,
          'fat': 0.0,
        },
        totalMicronutrients: {
          'sodium': 0.0,
          'cholesterol': 0.0,
          'fiber': 0.0,
          'sugar': 0.0,
        },
        meals: [],
      );
    }

    // Calculate totals
    int calories = 0;
    final macros = {
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
    };
    final micros = {
      'sodium': 0.0,
      'cholesterol': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
    };

    for (final meal in meals) {
      calories += meal.calories;
      
      // Sum macronutrients
      for (final entry in meal.macronutrients.entries) {
        macros[entry.key] = (macros[entry.key] ?? 0.0) + entry.value;
      }
      
      // Sum micronutrients
      for (final entry in meal.micronutrients.entries) {
        micros[entry.key] = (micros[entry.key] ?? 0.0) + entry.value;
      }
    }

    return DailyNutritionSummary(
      date: date,
      clientId: clientId,
      totalCalories: calories,
      totalMacronutrients: macros,
      totalMicronutrients: micros,
      meals: meals,
    );
  }
} 