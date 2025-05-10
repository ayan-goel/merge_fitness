import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';

class CalendlyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Calendly API endpoints
  static const String _baseUrl = 'https://api.calendly.com';
  static const String _scheduledEventsPath = '/scheduled_events';
  static const String _availabilityPath = '/availability';
  
  // Get the user's Calendly API token (stored in Firestore)
  Future<String?> _getCalendlyToken(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['calendlyToken'] as String?;
    } catch (e) {
      print('Error getting Calendly token: $e');
      return null;
    }
  }
  
  // Save a user's Calendly token
  Future<void> saveCalendlyToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      
      await _firestore.collection('users').doc(userId).update({
        'calendlyToken': token,
        'calendlyConnected': true,
      });
    } catch (e) {
      print('Error saving Calendly token: $e');
      throw Exception('Failed to save Calendly token');
    }
  }
  
  // Get a trainer's Calendly URL
  Future<String?> getTrainerCalendlyUrl(String trainerId) async {
    try {
      final doc = await _firestore.collection('users').doc(trainerId).get();
      final data = doc.data();
      return data?['calendlyUrl'] as String?;
    } catch (e) {
      print('Error getting trainer Calendly URL: $e');
      return null;
    }
  }
  
  // Save a trainer's Calendly URL
  Future<void> saveTrainerCalendlyUrl(String calendlyUrl) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      
      await _firestore.collection('users').doc(userId).update({
        'calendlyUrl': calendlyUrl,
      });
    } catch (e) {
      print('Error saving Calendly URL: $e');
      throw Exception('Failed to save Calendly URL');
    }
  }
  
  // Get available time slots from Calendly for a specific trainer
  Future<List<Map<String, dynamic>>> getTrainerAvailability(String trainerId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      // For the MVP, we'll use the Calendly embed approach rather than direct API calls
      // This is simpler as it doesn't require complex OAuth flows
      final trainerUrl = await getTrainerCalendlyUrl(trainerId);
      if (trainerUrl == null) {
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      // For real API integration, we would make a call like this:
      // final token = await _getCalendlyToken(trainerId);
      // final response = await http.get(
      //   Uri.parse('$_baseUrl$_availabilityPath'),
      //   headers: {'Authorization': 'Bearer $token'},
      // );
      
      // For now, return mock data
      return [
        {
          'start_time': DateTime.now().add(Duration(days: 1, hours: 9)),
          'end_time': DateTime.now().add(Duration(days: 1, hours: 10)),
        },
        {
          'start_time': DateTime.now().add(Duration(days: 1, hours: 11)),
          'end_time': DateTime.now().add(Duration(days: 1, hours: 12)),
        },
        {
          'start_time': DateTime.now().add(Duration(days: 2, hours: 14)),
          'end_time': DateTime.now().add(Duration(days: 2, hours: 15)),
        }
      ];
    } catch (e) {
      print('Error getting trainer availability: $e');
      throw Exception('Failed to get trainer availability');
    }
  }
  
  // Create a session in our Firestore database when scheduled through Calendly
  Future<TrainingSession> createSession({
    required String trainerId,
    required String clientId,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    String? notes,
  }) async {
    try {
      // Create session document
      final sessionRef = _firestore.collection('sessions').doc();
      
      final session = TrainingSession(
        id: sessionRef.id,
        trainerId: trainerId,
        clientId: clientId,
        startTime: startTime,
        endTime: endTime,
        location: location,
        status: 'scheduled',
        notes: notes,
        createdAt: DateTime.now(),
      );
      
      // Save to Firestore
      await sessionRef.set(session.toMap());
      
      // Add to activity feed
      await _addSessionToActivityFeed(session);
      
      return session;
    } catch (e) {
      print('Error creating session: $e');
      throw Exception('Failed to create session');
    }
  }
  
  // Add session to activity feed
  Future<void> _addSessionToActivityFeed(TrainingSession session) async {
    try {
      // Get client name
      final clientDoc = await _firestore.collection('users').doc(session.clientId).get();
      final clientName = clientDoc.data()?['displayName'] ?? 'Client';
      
      // Add to activity feed
      await _firestore.collection('activityFeed').add({
        'trainerId': session.trainerId,
        'type': 'session_scheduled',
        'message': '$clientName scheduled a session for ${_formatDateTime(session.startTime)}',
        'timestamp': FieldValue.serverTimestamp(),
        'relatedId': session.id,
      });
    } catch (e) {
      print('Error adding to activity feed: $e');
    }
  }
  
  // Get upcoming sessions for a client
  Future<List<TrainingSession>> getClientUpcomingSessions(String clientId) async {
    try {
      final now = DateTime.now();
      
      final snapshot = await _firestore.collection('sessions')
          .where('clientId', isEqualTo: clientId)
          .where('startTime', isGreaterThan: now)
          .orderBy('startTime')
          .get();
      
      return snapshot.docs.map((doc) => TrainingSession.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting client upcoming sessions: $e');
      return [];
    }
  }
  
  // Get all sessions for a trainer
  Future<List<TrainingSession>> getTrainerSessions(String trainerId) async {
    try {
      final snapshot = await _firestore.collection('sessions')
          .where('trainerId', isEqualTo: trainerId)
          .orderBy('startTime')
          .get();
      
      return snapshot.docs.map((doc) => TrainingSession.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting trainer sessions: $e');
      return [];
    }
  }
  
  // Format datetime for display
  String _formatDateTime(DateTime dateTime) {
    final date = '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
    return '$date at $time';
  }
} 