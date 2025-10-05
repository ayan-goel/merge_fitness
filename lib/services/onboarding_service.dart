import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/onboarding_form_model.dart';

class OnboardingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection reference
  CollectionReference get _onboardingFormsCollection => _firestore.collection('onboardingForms');

  // Save onboarding form data
  Future<String> saveOnboardingForm(OnboardingFormModel formData) async {
    try {
      // Save form data to Firestore
      final docRef = await _onboardingFormsCollection.add(formData.toMap());
      return docRef.id;
    } catch (e) {
      print('Error saving onboarding form: $e');
      throw e;
    }
  }

  // Get onboarding form for a client
  Future<OnboardingFormModel?> getClientOnboardingForm(String clientId) async {
    try {
      final querySnapshot = await _onboardingFormsCollection
          .where('clientId', isEqualTo: clientId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        // Debug info
        print("Client onboarding form found: ${doc.id}");
        print("Gym setup photos found: ${data['gymSetupPhotos']?.length ?? 0}");
        if (data['gymSetupPhotos'] != null && (data['gymSetupPhotos'] as List).isNotEmpty) {
          print("First photo URL: ${(data['gymSetupPhotos'] as List).first}");
        }
        
        return OnboardingFormModel.fromMap(data, doc.id);
      }
      print("No onboarding form found for client: $clientId");
      return null;
    } catch (e) {
      print('Error getting onboarding form: $e');
      throw e;
    }
  }

  // Upload gym setup photo and return URL
  Future<String> uploadGymSetupPhoto(File photo, String clientId) async {
    try {
      // Create reference to the photo in storage
      final fileName = 'gym_setup_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('gymSetupPhotos/$clientId/$fileName');

      // Upload photo
      final uploadTask = await ref.putFile(photo);
      
      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading gym setup photo: $e');
      throw e;
    }
  }

  // Add gym setup photo URL to form
  Future<void> addGymSetupPhotoToForm(String formId, String photoUrl) async {
    try {
      await _onboardingFormsCollection.doc(formId).update({
        'gymSetupPhotos': FieldValue.arrayUnion([photoUrl]),
      });
    } catch (e) {
      print('Error adding photo to form: $e');
      throw e;
    }
  }

  // Update signature timestamp
  Future<void> updateSignatureTimestamp(String formId, String timestamp) async {
    try {
      await _onboardingFormsCollection.doc(formId).update({
        'signatureTimestamp': timestamp,
      });
    } catch (e) {
      print('Error updating signature: $e');
      throw e;
    }
  }

  // Update client onboarding form
  Future<void> updateClientOnboardingForm(String formId, OnboardingFormModel updatedForm) async {
    try {
      await _onboardingFormsCollection.doc(formId).update(updatedForm.toMap());
      print('Successfully updated onboarding form: $formId');
    } catch (e) {
      print('Error updating onboarding form: $e');
      throw e;
    }
  }
} 