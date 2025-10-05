import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import '../models/session_package_model.dart';
import '../models/payment_history_model.dart';
import '../models/session_model.dart';
import 'stripe_backend_service.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StripeBackendService _stripeBackend = StripeBackendService();

  // Get session package for a specific client-trainer relationship
  Future<SessionPackage?> getSessionPackage(String clientId, String trainerId) async {
    try {
      final query = await _firestore.collection('sessionPackages')
          .where('clientId', isEqualTo: clientId)
          .where('trainerId', isEqualTo: trainerId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return SessionPackage.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting session package: $e');
      return null;
    }
  }

  // Create or update session package
  Future<SessionPackage?> createOrUpdateSessionPackage({
    required String clientId,
    required String trainerId,
    required double costPerTenSessions,
    int? sessionsRemaining,
  }) async {
    try {
      final existingPackage = await getSessionPackage(clientId, trainerId);
      
      if (existingPackage != null) {
        // Update existing package
        final updatedPackage = existingPackage.copyWith(
          costPerTenSessions: costPerTenSessions,
          sessionsRemaining: sessionsRemaining ?? existingPackage.sessionsRemaining,
          updatedAt: DateTime.now(),
        );

        await _firestore.collection('sessionPackages')
            .doc(existingPackage.id)
            .update(updatedPackage.toMap());

        return updatedPackage;
      } else {
        // Create new package
        final newPackage = SessionPackage(
          id: '',
          clientId: clientId,
          trainerId: trainerId,
          costPerTenSessions: costPerTenSessions,
          sessionsRemaining: sessionsRemaining ?? 0,
          createdAt: DateTime.now(),
        );

        final docRef = await _firestore.collection('sessionPackages')
            .add(newPackage.toMap());

        return newPackage.copyWith(id: docRef.id);
      }
    } catch (e) {
      print('Error creating/updating session package: $e');
      return null;
    }
  }

  // Process payment with Stripe
  Future<Map<String, dynamic>?> createPaymentIntent({
    required String clientId,
    required String trainerId,
    required double amount,
    required String currency,
  }) async {
    try {
      // Use the backend service to create payment intent securely
      final paymentIntent = await _stripeBackend.createPaymentIntent(
        clientId: clientId,
        trainerId: trainerId,
        amount: amount,
        currency: currency,
      );

      return paymentIntent;
    } catch (e) {
      print('Error creating payment intent: $e');
      return null;
    }
  }

  // Confirm payment and update session package
  Future<bool> confirmPaymentAndAddSessions({
    required String clientId,
    required String trainerId,
    required String paymentIntentId,
    required double amount,
  }) async {
    try {
      // Get or create session package
      SessionPackage? package = await getSessionPackage(clientId, trainerId);
      
      if (package == null) {
        print('No session package found for client-trainer relationship');
        return false;
      }

      // Update sessions remaining
      final updatedPackage = package.copyWith(
        sessionsRemaining: package.sessionsRemaining + 10,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('sessionPackages')
          .doc(package.id)
          .update(updatedPackage.toMap());

      // Record payment history
      final paymentHistory = PaymentHistory(
        id: '',
        clientId: clientId,
        trainerId: trainerId,
        sessionPackageId: package.id,
        amount: amount,
        sessionsPurchased: 10,
        stripePaymentIntentId: paymentIntentId,
        status: 'completed',
        createdAt: DateTime.now(),
      );

      await _firestore.collection('paymentHistory')
          .add(paymentHistory.toMap());

      return true;
    } catch (e) {
      print('Error confirming payment: $e');
      return false;
    }
  }

  // Get payment history for a client-trainer relationship
  Stream<List<PaymentHistory>> getPaymentHistory(String clientId, String trainerId) {
    return _firestore.collection('paymentHistory')
        .where('clientId', isEqualTo: clientId)
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentHistory.fromFirestore(doc))
            .toList());
  }

  // Consume a session (when booking)
  Future<bool> consumeSession(String clientId, String trainerId) async {
    try {
      // Prefer a package linked to this trainer
      SessionPackage? package = await getSessionPackage(clientId, trainerId);

      // Fallback to any package with remaining sessions
      if (package == null || package.sessionsRemaining <= 0) {
        package = await _getAnyAvailableSessionPackage(clientId);
      }

      if (package == null || package.sessionsRemaining <= 0) {
        return false;
      }

      final updatedPackage = package.copyWith(
        sessionsRemaining: package.sessionsRemaining - 1,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('sessionPackages')
          .doc(package.id)
          .update(updatedPackage.toMap());

      return true;
    } catch (e) {
      print('Error consuming session: $e');
      return false;
    }
  }

  // Refund a session (when cancelling)
  Future<bool> refundSession(String clientId, String trainerId) async {
    try {
      // Prefer a package linked to this trainer
      SessionPackage? package = await getSessionPackage(clientId, trainerId);

      // Fallback to any package (last booked) if none found
      package ??= await _getAnyAvailableSessionPackage(clientId);

      if (package == null) {
        return false;
      }

      final updatedPackage = package.copyWith(
        sessionsRemaining: package.sessionsRemaining + 1,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('sessionPackages')
          .doc(package.id)
          .update(updatedPackage.toMap());

      return true;
    } catch (e) {
      print('Error refunding session: $e');
      return false;
    }
  }

  // Manually adjust sessions (trainer discretion)
  Future<bool> adjustSessions({
    required String clientId,
    required String trainerId,
    required int sessionChange,
  }) async {
    try {
      final package = await getSessionPackage(clientId, trainerId);
      
      if (package == null) {
        return false;
      }

      final newSessionCount = package.sessionsRemaining + sessionChange;
      if (newSessionCount < 0) {
        return false; // Can't go below 0 sessions
      }

      final updatedPackage = package.copyWith(
        sessionsRemaining: newSessionCount,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('sessionPackages')
          .doc(package.id)
          .update(updatedPackage.toMap());

      return true;
    } catch (e) {
      print('Error adjusting sessions: $e');
      return false;
    }
  }

  // Check if client can book a session (has remaining sessions)
  Future<bool> canBookSession(String clientId, String trainerId) async {
    // First try to find a package specific to this trainer
    SessionPackage? package = await getSessionPackage(clientId, trainerId);

    // If none (or no remaining sessions) fallback to *any* package that has sessions
    if (package == null || package.sessionsRemaining <= 0) {
      package = await _getAnyAvailableSessionPackage(clientId);
    }

    return package != null && package.sessionsRemaining > 0;
  }

  // Create default session package for new client-trainer relationship
  Future<SessionPackage?> createDefaultSessionPackage({
    required String clientId,
    required String trainerId,
  }) async {
    try {
      // Check if package already exists
      final existingPackage = await getSessionPackage(clientId, trainerId);
      if (existingPackage != null) {
        return existingPackage; // Package already exists
      }

      // Create new package with default $1000 cost
      final newPackage = SessionPackage(
        id: '',
        clientId: clientId,
        trainerId: trainerId,
        costPerTenSessions: 1000.0, // Default cost
        sessionsRemaining: 0, // Start with 0 sessions
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore.collection('sessionPackages')
          .add(newPackage.toMap());

      return newPackage.copyWith(id: docRef.id);
    } catch (e) {
      print('Error creating default session package: $e');
      return null;
    }
  }

  // Create session package with custom price (used during client approval)
  Future<SessionPackage?> createSessionPackageWithPrice({
    required String clientId,
    required String trainerId,
    required double costPerTenSessions,
  }) async {
    try {
      // Check if package already exists
      final existingPackage = await getSessionPackage(clientId, trainerId);
      if (existingPackage != null) {
        // Update existing package with new price
        await _firestore.collection('sessionPackages')
            .doc(existingPackage.id)
            .update({
              'costPerTenSessions': costPerTenSessions,
            });
        return existingPackage.copyWith(costPerTenSessions: costPerTenSessions);
      }

      // Create new package with specified cost
      final newPackage = SessionPackage(
        id: '',
        clientId: clientId,
        trainerId: trainerId,
        costPerTenSessions: costPerTenSessions,
        sessionsRemaining: 0, // Start with 0 sessions
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore.collection('sessionPackages')
          .add(newPackage.toMap());

      return newPackage.copyWith(id: docRef.id);
    } catch (e) {
      print('Error creating session package with price: $e');
      return null;
    }
  }

  // Handle session cancellation logic
  Future<bool> handleSessionCancellation({
    required TrainingSession session,
    required bool isTrainerCancelling,
  }) async {
    try {
      // Determine who should get the refund - for family sessions, it's the paying client (organizer)
      final refundClientId = session.payingClientId ?? session.clientId;
      
      // If trainer cancels, always refund the session
      if (isTrainerCancelling) {
        return await refundSession(refundClientId, session.trainerId);
      }

      // If client cancels, check timing
      final now = DateTime.now();
      final timeDifference = session.startTime.difference(now);
      
      // If more than 24 hours before session, refund
      if (timeDifference.inHours >= 24) {
        return await refundSession(refundClientId, session.trainerId);
      }

      // If less than 24 hours, no refund
      return true;
    } catch (e) {
      print('Error handling session cancellation: $e');
      return false;
    }
  }

   Future<SessionPackage?> _getAnyAvailableSessionPackage(String clientId) async {
     try {
       // Find *any* package for this client that still has remaining sessions
       final query = await _firestore.collection('sessionPackages')
           .where('clientId', isEqualTo: clientId)
           .get();

       for (final doc in query.docs) {
         final pkg = SessionPackage.fromFirestore(doc);
         if (pkg.sessionsRemaining > 0) {
           return pkg;
         }
       }
       return null;
     } catch (e) {
       print('Error getting any available session package: $e');
       return null;
     }
   }
} 