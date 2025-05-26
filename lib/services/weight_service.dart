import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/weight_entry_model.dart';
import '../models/user_model.dart';

class WeightService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection reference
  CollectionReference get _weightCollection => _firestore.collection('weightEntries');

  // Add a new weight entry (weight in kg)
  Future<WeightEntry> addWeightEntry(double weight, {UserModel? user, String? notes}) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // If user is provided, calculate BMI
    double? bmi;
    if (user != null && user.height != null) {
      bmi = WeightEntry.calculateBMI(weight, user.height!);
    }

    // Create entry data
    final entry = WeightEntry(
      id: '', // Will be set by Firestore
      userId: currentUserId!,
      weight: weight,
      date: DateTime.now(),
      bmi: bmi,
      notes: notes,
    );

    // Save to Firestore
    final docRef = await _weightCollection.add(entry.toFirestore());
    
    // Return the entry with the ID set
    return WeightEntry(
      id: docRef.id,
      userId: entry.userId,
      weight: entry.weight,
      date: entry.date,
      bmi: entry.bmi,
      notes: entry.notes,
    );
  }
  
  // Add a new weight entry with weight in pounds
  Future<WeightEntry> addWeightEntryInPounds(double weightInPounds, {UserModel? user, String? notes}) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Convert pounds to kg for storage
    double weightInKg = WeightEntry.poundsToKg(weightInPounds);
    
    // If user is provided, calculate BMI
    double? bmi;
    if (user != null && user.height != null) {
      bmi = WeightEntry.calculateBMI(weightInKg, user.height!);
    }

    // Create entry data
    final entry = WeightEntry(
      id: '', // Will be set by Firestore
      userId: currentUserId!,
      weight: weightInKg, // Store in kg
      date: DateTime.now(),
      bmi: bmi,
      notes: notes,
    );

    // Save to Firestore
    final docRef = await _weightCollection.add(entry.toFirestore());
    
    // Return the entry with the ID set
    return WeightEntry(
      id: docRef.id,
      userId: entry.userId,
      weight: entry.weight,
      date: entry.date,
      bmi: entry.bmi,
      notes: entry.notes,
    );
  }

  // Get all weight entries for the current user
  Future<List<WeightEntry>> getWeightEntries() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final snapshot = await _weightCollection
        .where('userId', isEqualTo: currentUserId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => WeightEntry.fromFirestore(doc)).toList();
  }

  // Get all weight entries for a specific client (for trainers)
  Future<List<WeightEntry>> getWeightEntriesForClient(String clientId) async {
    final snapshot = await _weightCollection
        .where('userId', isEqualTo: clientId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => WeightEntry.fromFirestore(doc)).toList();
  }

  // Get weight entries for a specific date range
  Future<List<WeightEntry>> getWeightEntriesInRange(DateTime startDate, DateTime endDate) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final snapshot = await _weightCollection
        .where('userId', isEqualTo: currentUserId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date')
        .get();

    return snapshot.docs.map((doc) => WeightEntry.fromFirestore(doc)).toList();
  }

  // Get today's weight entry if it exists
  Future<WeightEntry?> getTodayWeightEntry() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Get today's date range
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final snapshot = await _weightCollection
        .where('userId', isEqualTo: currentUserId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return WeightEntry.fromFirestore(snapshot.docs.first);
  }

  // Delete a weight entry
  Future<void> deleteWeightEntry(String entryId) async {
    await _weightCollection.doc(entryId).delete();
  }

  // Update a weight entry
  Future<void> updateWeightEntry(WeightEntry entry) async {
    await _weightCollection.doc(entry.id).update(entry.toFirestore());
  }

  // Get the latest weight entry
  Future<WeightEntry?> getLatestWeightEntry() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final snapshot = await _weightCollection
        .where('userId', isEqualTo: currentUserId)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return WeightEntry.fromFirestore(snapshot.docs.first);
  }

  // Stream of weight entries
  Stream<List<WeightEntry>> streamWeightEntries() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _weightCollection
        .where('userId', isEqualTo: currentUserId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => WeightEntry.fromFirestore(doc)).toList();
        });
  }
} 