import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class StripeBackendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  /// Create a payment intent via Firebase Cloud Functions
  Future<Map<String, dynamic>?> createPaymentIntent({
    required String clientId,
    required String trainerId,
    required double amount,
    required String currency,
  }) async {
    try {
      print('Creating payment intent via Cloud Functions...');
      
      final callable = _functions.httpsCallable('createPaymentIntent');
      final result = await callable.call({
        'amount': amount,
        'currency': currency,
        'clientId': clientId,
        'trainerId': trainerId,
      });
      
      print('Payment intent created successfully: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('Error creating payment intent via Cloud Functions: $e');
      
      // Provide helpful error messages for common issues
      if (e.toString().contains('UNAUTHENTICATED')) {
        throw Exception('User must be logged in to create payment intent');
      } else if (e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('User does not have permission to create payment intent');
      } else if (e.toString().contains('INVALID_ARGUMENT')) {
        throw Exception('Invalid payment details provided');
      } else if (e.toString().contains('NOT_FOUND')) {
        throw Exception('Cloud Function not found. Please ensure it\'s deployed.');
      }
      
      throw Exception('Failed to create payment intent: $e');
    }
  }

  /// Confirm a payment intent via Firebase Cloud Functions
  Future<Map<String, dynamic>?> confirmPaymentIntent(String paymentIntentId) async {
    try {
      print('Confirming payment intent via Cloud Functions...');
      
      final callable = _functions.httpsCallable('confirmPaymentIntent');
      final result = await callable.call({
        'paymentIntentId': paymentIntentId,
      });
      
      print('Payment intent confirmed successfully: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('Error confirming payment intent via Cloud Functions: $e');
      return null;
    }
  }

  /// Get payment intent status via Firebase Cloud Functions
  Future<Map<String, dynamic>?> getPaymentIntent(String paymentIntentId) async {
    try {
      print('Getting payment intent via Cloud Functions...');
      
      final callable = _functions.httpsCallable('getPaymentIntent');
      final result = await callable.call({
        'paymentIntentId': paymentIntentId,
      });
      
      print('Payment intent retrieved successfully: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('Error getting payment intent via Cloud Functions: $e');
      return null;
    }
  }
} 