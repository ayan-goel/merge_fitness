import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
  other,
}

class FoodLog {
  final String id;
  final String userId;
  final DateTime timestamp;
  final MealType mealType;
  final String? photoUrl;
  final String? description;
  final String? suggestedSwapId;
  final String? notes;

  FoodLog({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.mealType,
    this.photoUrl,
    this.description,
    this.suggestedSwapId,
    this.notes,
  });

  factory FoodLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return FoodLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      mealType: _stringToMealType(data['mealType'] ?? 'other'),
      photoUrl: data['photoUrl'],
      description: data['description'],
      suggestedSwapId: data['suggestedSwapId'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'mealType': _mealTypeToString(mealType),
      'photoUrl': photoUrl,
      'description': description,
      'suggestedSwapId': suggestedSwapId,
      'notes': notes,
    };
  }

  // Helper to convert string to MealType enum
  static MealType _stringToMealType(String mealTypeStr) {
    switch (mealTypeStr.toLowerCase()) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
      default:
        return MealType.other;
    }
  }

  // Helper to convert MealType enum to string
  static String _mealTypeToString(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
      case MealType.other:
        return 'other';
    }
  }

  // Create a copy with updated values
  FoodLog copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    MealType? mealType,
    String? photoUrl,
    String? description,
    String? suggestedSwapId,
    String? notes,
  }) {
    return FoodLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      mealType: mealType ?? this.mealType,
      photoUrl: photoUrl ?? this.photoUrl,
      description: description ?? this.description,
      suggestedSwapId: suggestedSwapId ?? this.suggestedSwapId,
      notes: notes ?? this.notes,
    );
  }
}

// Food swap suggestion model
class FoodSwap {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? nutritionalInfo;
  final bool isTrainerApproved;

  FoodSwap({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.nutritionalInfo,
    this.isTrainerApproved = false,
  });

  factory FoodSwap.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return FoodSwap(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      imageUrl: data['imageUrl'],
      nutritionalInfo: data['nutritionalInfo'],
      isTrainerApproved: data['isTrainerApproved'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'nutritionalInfo': nutritionalInfo,
      'isTrainerApproved': isTrainerApproved,
    };
  }
} 