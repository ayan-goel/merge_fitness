import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../models/session_model.dart';

class CalendlyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Calendly API endpoints
  static const String _baseUrl = 'https://api.calendly.com';
  static const String _scheduledEventsPath = '/scheduled_events';
  static const String _eventTypesPath = '/event_types';
  static const String _userPath = '/users/me';
  static const String _availabilityPath = '/event_type_available_times';
  
  // Calendly OAuth configuration
  static const String _authUrl = 'https://auth.calendly.com/oauth/authorize';
  static const String _tokenUrl = 'https://auth.calendly.com/oauth/token';
  
  // Replace these with your own values from Calendly Developer Portal
  static const String _clientId = 'g06lkWm61e-4wZlg0Ss2tX7dKdyIVnobH_dDHyw2JjI';
  static const String _clientSecret = '3nX6RhWnACvnEZOTy-jsaz1jO48P7cFBCIcDt7_FceE';
  static const String _redirectUri = 'mergefitness://oauth/callback';
  
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
  Future<void> saveCalendlyToken(String token, {String? calendlyUri}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      
      // Get user info from Calendly
      final userInfo = await _getCalendlyUserInfo(token);
      
      await _firestore.collection('users').doc(userId).update({
        'calendlyToken': token,
        'calendlyConnected': true,
        'calendlyUri': calendlyUri ?? userInfo['resource']['uri'],
        'calendlySchedulingUrl': userInfo['resource']['scheduling_url'],
      });
    } catch (e) {
      print('Error saving Calendly token: $e');
      throw Exception('Failed to save Calendly token: $e');
    }
  }
  
  // Get user info from Calendly
  Future<Map<String, dynamic>> _getCalendlyUserInfo(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_userPath'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get user info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting user info: $e');
      throw Exception('Failed to get user info: $e');
    }
  }
  
  // Start the OAuth flow
  Future<void> connectCalendlyAccount() async {
    try {
      final authUrl = Uri.parse(
        '$_authUrl?client_id=$_clientId&response_type=code&redirect_uri=$_redirectUri'
      );
      
      // Launch OAuth flow using flutter_web_auth_2
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: 'mergefitness',
      );
      
      // Extract the authorization code from the result
      final Uri resultUri = Uri.parse(result);
      final String? code = resultUri.queryParameters['code'];
      
      if (code != null) {
        // Exchange code for token
        final tokenResponse = await http.post(
          Uri.parse(_tokenUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'client_id': _clientId,
            'client_secret': _clientSecret,
            'code': code,
            'grant_type': 'authorization_code',
            'redirect_uri': _redirectUri,
          },
        );
        
        if (tokenResponse.statusCode == 200) {
          final tokenData = jsonDecode(tokenResponse.body);
          final accessToken = tokenData['access_token'];
          
          // Save token to Firestore
          await saveCalendlyToken(accessToken);
        } else {
          throw Exception('Failed to get token: ${tokenResponse.statusCode} - Body: ${tokenResponse.body}');
        }
      } else {
        throw Exception('No authorization code received');
      }
    } catch (e) {
      print('Error connecting Calendly account: $e');
      throw Exception('Failed to connect Calendly account: $e');
    }
  }
  
  // Get a trainer's Calendly URI
  Future<String?> getTrainerCalendlyUri(String trainerId) async {
    try {
      final doc = await _firestore.collection('users').doc(trainerId).get();
      final data = doc.data();
      return data?['calendlyUri'] as String?;
    } catch (e) {
      print('Error getting trainer Calendly URI: $e');
      return null;
    }
  }
  
  // Get a trainer's Calendly scheduling URL
  Future<String?> getTrainerCalendlyUrl(String trainerId) async {
    try {
      final doc = await _firestore.collection('users').doc(trainerId).get();
      final data = doc.data();
      return data?['calendlySchedulingUrl'] as String?;
    } catch (e) {
      print('Error getting trainer Calendly URL: $e');
      return null;
    }
  }
  
  // Get event types for a trainer
  Future<List<Map<String, dynamic>>> getTrainerEventTypes(String trainerId) async {
    try {
      final token = await _getCalendlyToken(trainerId);
      if (token == null) {
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      final uri = await getTrainerCalendlyUri(trainerId);
      if (uri == null) {
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      final response = await http.get(
        Uri.parse('$_baseUrl$_eventTypesPath?user=$uri'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['collection']);
      } else {
        throw Exception('Failed to get event types: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting trainer event types: $e');
      throw Exception('Failed to get trainer event types: $e');
    }
  }
  
  // Get available time slots from Calendly for a specific trainer
  Future<List<Map<String, dynamic>>> getTrainerAvailability(String trainerId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final token = await _getCalendlyToken(trainerId);
      if (token == null) {
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      // Get event types for the trainer
      final eventTypes = await getTrainerEventTypes(trainerId);
      if (eventTypes.isEmpty) {
        throw Exception('Trainer has no event types configured');
      }
      
      // Use the first event type (usually 1:1 meeting)
      final eventTypeUri = eventTypes[0]['uri'];
      
      // Set date range (default to next 7 days)
      final start = startDate ?? DateTime.now();
      final end = endDate ?? start.add(const Duration(days: 7));
      
      // Format dates for Calendly API
      final startTime = start.toUtc().toIso8601String();
      final endTime = end.toUtc().toIso8601String();
      
      // Call API to get available times
      final response = await http.get(
        Uri.parse('$_baseUrl$_availabilityPath?event_type=$eventTypeUri&start_time=$startTime&end_time=$endTime'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Transform into our expected format
        return List<Map<String, dynamic>>.from(data['collection']).map((slot) {
          final startTime = DateTime.parse(slot['start_time']);
          final endTime = DateTime.parse(slot['end_time']);
          
          return {
            'start_time': startTime,
            'end_time': endTime,
            'status': slot['status'],
            'spot_number': slot['spot_number'] ?? 1,
          };
        }).toList();
      } else {
        throw Exception('Failed to get availability: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error getting trainer availability: $e');
      throw Exception('Failed to get trainer availability: $e');
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
    String? calendlyEventUri,
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
        calendlyEventUri: calendlyEventUri,
        createdAt: DateTime.now(),
      );
      
      // Save to Firestore
      await sessionRef.set(session.toMap());
      
      // Add to activity feed
      await _addSessionToActivityFeed(session);
      
      return session;
    } catch (e) {
      print('Error creating session: $e');
      throw Exception('Failed to create session: $e');
    }
  }
  
  // Schedule a session using the Calendly API
  Future<TrainingSession> scheduleSession({
    required String trainerId,
    required String clientId,
    required Map<String, dynamic> timeSlot,
    required String location,
    String? notes,
  }) async {
    try {
      final token = await _getCalendlyToken(trainerId);
      if (token == null) {
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      // Get client info
      final clientDoc = await _firestore.collection('users').doc(clientId).get();
      final clientData = clientDoc.data();
      
      if (clientData == null) {
        throw Exception('Client not found');
      }
      
      // For now, we'll create the event in our database without using the Calendly scheduling API
      // In a complete implementation, you would use Calendly's scheduling API to create the event
      
      return await createSession(
        trainerId: trainerId,
        clientId: clientId,
        startTime: timeSlot['start_time'],
        endTime: timeSlot['end_time'],
        location: location,
        notes: notes,
      );
    } catch (e) {
      print('Error scheduling session: $e');
      throw Exception('Failed to schedule session: $e');
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
      // Continue even if there's an error - this is just activity logging
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
      
      // If the error is about indexes building, try an alternative approach
      if (e.toString().contains('index is currently building') || 
          e.toString().contains('requires an index')) {
        try {
          // Get without ordering (works without index)
          final snapshot = await _firestore.collection('sessions')
              .where('clientId', isEqualTo: clientId)
              .get();
          
          final now = DateTime.now();
          // Filter and sort manually
          final sessions = snapshot.docs
              .map((doc) => TrainingSession.fromFirestore(doc))
              .where((session) => session.startTime.isAfter(now))
              .toList();
          
          sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
          return sessions;
        } catch (fallbackError) {
          print('Fallback error getting client sessions: $fallbackError');
          return [];
        }
      }
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
      
      // If the error is about indexes building, try an alternative approach
      if (e.toString().contains('index is currently building') || 
          e.toString().contains('requires an index')) {
        try {
          // Get without ordering (works without index)
          final snapshot = await _firestore.collection('sessions')
              .where('trainerId', isEqualTo: trainerId)
              .get();
          
          // Manual sorting
          final sessions = snapshot.docs.map((doc) => TrainingSession.fromFirestore(doc)).toList();
          sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
          return sessions;
        } catch (fallbackError) {
          print('Fallback error getting trainer sessions: $fallbackError');
          return [];
        }
      }
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
  
  // Get all available trainers for scheduling
  Future<List<Map<String, dynamic>>> getAvailableTrainers() async {
    try {
      // Get trainers who have connected their Calendly
      final snapshot = await _firestore.collection('users')
          .where('role', isEqualTo: 'trainer')
          .where('calendlyConnected', isEqualTo: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'displayName': data['displayName'] ?? 'Trainer',
          'calendlyUrl': data['calendlySchedulingUrl'] ?? '',
          'photoUrl': data['photoUrl'],
          'specialty': data['specialty'] ?? 'General Fitness',
        };
      }).toList();
    } catch (e) {
      print('Error getting available trainers: $e');
      throw Exception('Failed to load trainers: $e');
    }
  }
} 