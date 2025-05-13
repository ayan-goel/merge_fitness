import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_entry_model.dart';
import '../models/nutrition_plan_model.dart';
import 'nutrition_service.dart';

class MealService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NutritionService _nutritionService = NutritionService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference get _mealsCollection => _firestore.collection('meals');
  
  // Add a new meal entry
  Future<MealEntry> addMealEntry(MealEntry meal) async {
    final docRef = await _mealsCollection.add(meal.toMap());
    
    // Update the document with the correct ID
    final newMeal = meal.copyWith(id: docRef.id);
    await docRef.update({'id': docRef.id});
    
    return newMeal;
  }
  
  // Update an existing meal entry
  Future<void> updateMealEntry(MealEntry meal) async {
    await _mealsCollection.doc(meal.id).update(meal.toMap());
  }
  
  // Delete a meal entry
  Future<void> deleteMealEntry(String mealId) async {
    await _mealsCollection.doc(mealId).delete();
  }
  
  // Get all meal entries for a client on a specific date
  Stream<List<MealEntry>> getClientMealsForDate(String clientId, DateTime date) {
    // Normalize date to start of day for comparison
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    
    return _mealsCollection
        .where('clientId', isEqualTo: clientId)
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThanOrEqualTo: endOfDay)
        .orderBy('date')
        .orderBy('timeConsumed')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MealEntry.fromFirestore(doc))
              .toList();
        });
  }
  
  // Get daily nutrition summary for a client on a specific date
  Stream<DailyNutritionSummary> getDailyNutritionSummary(String clientId, DateTime date) {
    return getClientMealsForDate(clientId, date)
        .map((meals) => DailyNutritionSummary.fromMeals(meals, date, clientId));
  }
  
  // Get a specific meal entry
  Future<MealEntry?> getMealEntry(String mealId) async {
    final doc = await _mealsCollection.doc(mealId).get();
    if (!doc.exists) return null;
    return MealEntry.fromFirestore(doc);
  }
  
  // Get meal entries for a date range (for weekly/monthly reports)
  Stream<List<MealEntry>> getClientMealsForDateRange(String clientId, DateTime startDate, DateTime endDate) {
    // Normalize dates
    final normalizedStartDate = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    
    return _mealsCollection
        .where('clientId', isEqualTo: clientId)
        .where('date', isGreaterThanOrEqualTo: normalizedStartDate)
        .where('date', isLessThanOrEqualTo: normalizedEndDate)
        .orderBy('date')
        .orderBy('timeConsumed')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MealEntry.fromFirestore(doc))
              .toList();
        });
  }
  
  // Calculate nutrition progress against the client's plan
  Stream<Map<String, double>> calculateNutritionProgress(String clientId, DateTime date) async* {
    // Get the active nutrition plan
    final activePlan = await _nutritionService.getCurrentNutritionPlan(clientId);
    
    // Listen to meals for the day
    yield* getClientMealsForDate(clientId, date).map((meals) {
      final result = <String, double>{
        'calories': 0.0,
        'protein': 0.0,
        'carbs': 0.0,
        'fat': 0.0,
        'sodium': 0.0,
        'cholesterol': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
      };
      
      if (activePlan == null) {
        return result;
      }
      
      // Create summary from meals
      final summary = DailyNutritionSummary.fromMeals(meals, date, clientId);
      
      // Calculate progress percentages
      
      // Calories progress
      result['calories'] = activePlan.dailyCalories > 0 
          ? summary.totalCalories / activePlan.dailyCalories 
          : 0.0;
      
      // Macronutrients progress
      for (final nutrient in ['protein', 'carbs', 'fat']) {
        final target = activePlan.macronutrients[nutrient] ?? 0.0;
        final current = summary.totalMacronutrients[nutrient] ?? 0.0;
        result[nutrient] = target > 0 ? current / target : 0.0;
      }
      
      // Micronutrients progress
      for (final nutrient in ['sodium', 'cholesterol', 'fiber', 'sugar']) {
        final target = activePlan.micronutrients[nutrient] ?? 0.0;
        final current = summary.totalMicronutrients[nutrient] ?? 0.0;
        result[nutrient] = target > 0 ? current / target : 0.0;
      }
      
      return result;
    });
  }
} 