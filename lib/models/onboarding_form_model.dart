import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingFormModel {
  final String? id;
  final String clientId;
  final String clientName;
  final String? phoneNumber;
  final String? email;
  final String? address;
  final DateTime? dateOfBirth;
  final double? height; // in cm
  final double? weight; // in kg
  final String? emergencyContact;
  final String? emergencyPhone;
  
  // Medical history
  final bool? hasHeartDisease;
  final bool? hasBreathingIssues;
  final String? lastPhysicalDate;
  final String? lastPhysicalResult;
  final bool? hasDoctorNoteHeartTrouble;
  final bool? hasAnginaPectoris;
  final bool? hasHeartPalpitations;
  final bool? hasHeartAttack;
  final bool? hasDiabetesOrHighBloodPressure;
  final bool? hasHeartDiseaseInFamily;
  final bool? hasCholesterolMedication;
  final bool? hasHeartMedication;
  final bool? sleepsWell;
  final bool? drinksDailyAlcohol;
  final bool? smokescigarettes;
  final bool? hasPhysicalCondition;
  final bool? hasJointOrMuscleProblems;
  final bool? isPregnant;
  
  // Additional information
  final String? additionalMedicalInfo;
  final String? exerciseFrequency;
  final String? medications;
  final String? healthGoals;
  final String? stressLevel;
  final String? bestLifePoint;
  final List<String> regularFoods;
  final String? eatingHabits;
  final String? typicalBreakfast;
  final String? typicalLunch;
  final String? typicalDinner;
  final String? typicalSnacks;
  
  // Fitness ratings (1-10)
  final int? cardioRespiratoryRating;
  final int? strengthRating;
  final int? enduranceRating;
  final int? flexibilityRating;
  final int? powerRating;
  final int? bodyCompositionRating;
  final int? selfImageRating;
  
  final String? additionalNotes;
  
  // Signature
  final String? signatureTimestamp;
  
  // Gym setup photos
  final List<String> gymSetupPhotos;

  OnboardingFormModel({
    this.id,
    required this.clientId,
    required this.clientName,
    this.phoneNumber,
    this.email,
    this.address,
    this.dateOfBirth,
    this.height,
    this.weight,
    this.emergencyContact,
    this.emergencyPhone,
    this.hasHeartDisease,
    this.hasBreathingIssues,
    this.lastPhysicalDate,
    this.lastPhysicalResult,
    this.hasDoctorNoteHeartTrouble,
    this.hasAnginaPectoris,
    this.hasHeartPalpitations,
    this.hasHeartAttack,
    this.hasDiabetesOrHighBloodPressure,
    this.hasHeartDiseaseInFamily,
    this.hasCholesterolMedication,
    this.hasHeartMedication,
    this.sleepsWell,
    this.drinksDailyAlcohol,
    this.smokescigarettes,
    this.hasPhysicalCondition,
    this.hasJointOrMuscleProblems,
    this.isPregnant,
    this.additionalMedicalInfo,
    this.exerciseFrequency,
    this.medications,
    this.healthGoals,
    this.stressLevel,
    this.bestLifePoint,
    this.regularFoods = const [],
    this.eatingHabits,
    this.typicalBreakfast,
    this.typicalLunch,
    this.typicalDinner,
    this.typicalSnacks,
    this.cardioRespiratoryRating,
    this.strengthRating,
    this.enduranceRating,
    this.flexibilityRating,
    this.powerRating,
    this.bodyCompositionRating,
    this.selfImageRating,
    this.additionalNotes,
    this.signatureTimestamp,
    this.gymSetupPhotos = const [],
  });

  factory OnboardingFormModel.fromMap(Map<String, dynamic> map, String id) {
    return OnboardingFormModel(
      id: id,
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      phoneNumber: map['phoneNumber'],
      email: map['email'],
      address: map['address'],
      dateOfBirth: map['dateOfBirth'] != null ? (map['dateOfBirth'] as Timestamp).toDate() : null,
      height: map['height']?.toDouble(),
      weight: map['weight']?.toDouble(),
      emergencyContact: map['emergencyContact'],
      emergencyPhone: map['emergencyPhone'],
      hasHeartDisease: map['hasHeartDisease'],
      hasBreathingIssues: map['hasBreathingIssues'],
      lastPhysicalDate: map['lastPhysicalDate'],
      lastPhysicalResult: map['lastPhysicalResult'],
      hasDoctorNoteHeartTrouble: map['hasDoctorNoteHeartTrouble'],
      hasAnginaPectoris: map['hasAnginaPectoris'],
      hasHeartPalpitations: map['hasHeartPalpitations'],
      hasHeartAttack: map['hasHeartAttack'],
      hasDiabetesOrHighBloodPressure: map['hasDiabetesOrHighBloodPressure'],
      hasHeartDiseaseInFamily: map['hasHeartDiseaseInFamily'],
      hasCholesterolMedication: map['hasCholesterolMedication'],
      hasHeartMedication: map['hasHeartMedication'],
      sleepsWell: map['sleepsWell'],
      drinksDailyAlcohol: map['drinksDailyAlcohol'],
      smokescigarettes: map['smokescigarettes'],
      hasPhysicalCondition: map['hasPhysicalCondition'],
      hasJointOrMuscleProblems: map['hasJointOrMuscleProblems'],
      isPregnant: map['isPregnant'],
      additionalMedicalInfo: map['additionalMedicalInfo'],
      exerciseFrequency: map['exerciseFrequency'],
      medications: map['medications'],
      healthGoals: map['healthGoals'],
      stressLevel: map['stressLevel'],
      bestLifePoint: map['bestLifePoint'],
      regularFoods: List<String>.from(map['regularFoods'] ?? []),
      eatingHabits: map['eatingHabits'],
      typicalBreakfast: map['typicalBreakfast'],
      typicalLunch: map['typicalLunch'],
      typicalDinner: map['typicalDinner'],
      typicalSnacks: map['typicalSnacks'],
      cardioRespiratoryRating: map['cardioRespiratoryRating'],
      strengthRating: map['strengthRating'],
      enduranceRating: map['enduranceRating'],
      flexibilityRating: map['flexibilityRating'],
      powerRating: map['powerRating'],
      bodyCompositionRating: map['bodyCompositionRating'],
      selfImageRating: map['selfImageRating'],
      additionalNotes: map['additionalNotes'],
      signatureTimestamp: map['signatureTimestamp'],
      gymSetupPhotos: List<String>.from(map['gymSetupPhotos'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'height': height,
      'weight': weight,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'hasHeartDisease': hasHeartDisease,
      'hasBreathingIssues': hasBreathingIssues,
      'lastPhysicalDate': lastPhysicalDate,
      'lastPhysicalResult': lastPhysicalResult,
      'hasDoctorNoteHeartTrouble': hasDoctorNoteHeartTrouble,
      'hasAnginaPectoris': hasAnginaPectoris,
      'hasHeartPalpitations': hasHeartPalpitations,
      'hasHeartAttack': hasHeartAttack,
      'hasDiabetesOrHighBloodPressure': hasDiabetesOrHighBloodPressure,
      'hasHeartDiseaseInFamily': hasHeartDiseaseInFamily,
      'hasCholesterolMedication': hasCholesterolMedication,
      'hasHeartMedication': hasHeartMedication,
      'sleepsWell': sleepsWell,
      'drinksDailyAlcohol': drinksDailyAlcohol,
      'smokescigarettes': smokescigarettes,
      'hasPhysicalCondition': hasPhysicalCondition,
      'hasJointOrMuscleProblems': hasJointOrMuscleProblems,
      'isPregnant': isPregnant,
      'additionalMedicalInfo': additionalMedicalInfo,
      'exerciseFrequency': exerciseFrequency,
      'medications': medications,
      'healthGoals': healthGoals,
      'stressLevel': stressLevel,
      'bestLifePoint': bestLifePoint,
      'regularFoods': regularFoods,
      'eatingHabits': eatingHabits,
      'typicalBreakfast': typicalBreakfast,
      'typicalLunch': typicalLunch,
      'typicalDinner': typicalDinner,
      'typicalSnacks': typicalSnacks,
      'cardioRespiratoryRating': cardioRespiratoryRating,
      'strengthRating': strengthRating,
      'enduranceRating': enduranceRating,
      'flexibilityRating': flexibilityRating,
      'powerRating': powerRating,
      'bodyCompositionRating': bodyCompositionRating,
      'selfImageRating': selfImageRating,
      'additionalNotes': additionalNotes,
      'signatureTimestamp': signatureTimestamp,
      'gymSetupPhotos': gymSetupPhotos,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
} 