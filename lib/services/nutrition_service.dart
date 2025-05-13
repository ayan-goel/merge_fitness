import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/nutrition_plan_model.dart';

class NutritionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference get _nutritionPlansCollection => _firestore.collection('nutritionPlans');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Create a new nutrition plan
  Future<NutritionPlan> createNutritionPlan(NutritionPlan plan) async {
    // First check if there's an existing active plan for this client
    final existingPlan = await getCurrentNutritionPlan(plan.clientId);
    
    // If there's an existing plan, delete it first
    if (existingPlan != null) {
      await deleteNutritionPlan(existingPlan.id);
    }
    
    final docRef = await _nutritionPlansCollection.add(plan.toMap());
    
    // Update the plan with the new ID
    final newPlan = plan.copyWith(id: docRef.id);
    
    // Update the document with the correct ID
    await docRef.update({'id': docRef.id});
    
    return newPlan;
  }

  // Get all nutrition plans for a client
  Stream<List<NutritionPlan>> getClientNutritionPlans(String clientId) {
    return _nutritionPlansCollection
        .where('clientId', isEqualTo: clientId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NutritionPlan.fromFirestore(doc))
              .toList();
        });
  }

  // Get a specific nutrition plan
  Future<NutritionPlan?> getNutritionPlan(String planId) async {
    final doc = await _nutritionPlansCollection.doc(planId).get();
    if (!doc.exists) return null;
    return NutritionPlan.fromFirestore(doc);
  }

  // Get current active nutrition plan for a client
  Future<NutritionPlan?> getCurrentNutritionPlan(String clientId) async {
    final today = DateTime.now();
    
    final snapshot = await _nutritionPlansCollection
        .where('clientId', isEqualTo: clientId)
        .where('startDate', isLessThanOrEqualTo: today)
        .orderBy('startDate', descending: true)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    
    final plan = NutritionPlan.fromFirestore(snapshot.docs.first);
    
    // Check if plan is still active (if it has an end date)
    if (plan.endDate != null && plan.endDate!.isBefore(today)) {
      return null; // Plan has expired
    }
    
    return plan;
  }

  // Check if a client has an active nutrition plan
  Future<bool> hasActiveNutritionPlan(String clientId) async {
    final currentPlan = await getCurrentNutritionPlan(clientId);
    return currentPlan != null;
  }

  // Update a nutrition plan
  Future<void> updateNutritionPlan(NutritionPlan plan) async {
    await _nutritionPlansCollection.doc(plan.id).update(plan.toMap());
  }

  // Delete a nutrition plan
  Future<void> deleteNutritionPlan(String planId) async {
    // Get the plan first to access client and trainer info
    final planDoc = await _nutritionPlansCollection.doc(planId).get();
    if (!planDoc.exists) {
      throw Exception('Nutrition plan not found');
    }
    
    final plan = NutritionPlan.fromFirestore(planDoc);
    
    // Delete the plan
    await _nutritionPlansCollection.doc(planId).delete();
  }
} 