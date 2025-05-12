import 'dart:convert';
import 'dart:math'; // For random string generation and min function
import 'package:crypto/crypto.dart'; // For SHA256
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
  static const String _clientId = 'FIy98L4pyGDAtdpzjlOa16YzXmLZjHBj_CtRg2KJeos';
  static const String _clientSecret = 't119SRTQW8MtUmP7gV-c1Iys3pgrKaAUVn-jm5GlSAY';
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
  
  // Disconnect a user's Calendly account
  Future<void> disconnectCalendlyAccount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      
      await _firestore.collection('users').doc(userId).update({
        'calendlyToken': FieldValue.delete(),
        'calendlyConnected': false,
        'calendlyUri': FieldValue.delete(),
        'calendlySchedulingUrl': FieldValue.delete(),
        'selectedCalendlyEventType': FieldValue.delete(),
      });
    } catch (e) {
      print('Error disconnecting Calendly account: $e');
      throw Exception('Failed to disconnect Calendly account: $e');
    }
  }
  
  // Save a user's Calendly token
  Future<void> saveCalendlyToken(String token, {String? calendlyUri, String? selectedEventTypeUri}) async {
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
        'selectedCalendlyEventType': selectedEventTypeUri,
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
  
  // Helper function to generate a random string for code_verifier
  String _generateRandomString(int len) {
    final random = Random.secure();
    final values = List<int>.generate(len, (i) => random.nextInt(256));
    return base64UrlEncode(values).substring(0, len); // Ensure it's URL safe and of desired length
  }
  
  // Start the OAuth flow
  Future<void> connectCalendlyAccount() async {
    try {
      // PKCE: Generate code verifier and challenge
      final String codeVerifier = _generateRandomString(128); // Standard length is 43-128
      final String codeChallenge = base64UrlEncode(sha256.convert(utf8.encode(codeVerifier)).bytes)
                                      .replaceAll('=', ''); // Remove padding for base64url

      final authUrl = Uri.parse(
        '$_authUrl?client_id=$_clientId&response_type=code&redirect_uri=$_redirectUri&code_challenge=$codeChallenge&code_challenge_method=S256' // Added PKCE params
      );
      
      print('CalendlyService: Constructed authUrl: ${authUrl.toString()}');
      print('CalendlyService: PKCE Code Verifier (DO NOT LOG IN PRODUCTION): $codeVerifier');

      
      // Launch OAuth flow using flutter_web_auth_2
      String result;
      try {
        print('CalendlyService: Attempting FlutterWebAuth2.authenticate...');
        result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: 'mergefitness',
      );
        print('CalendlyService: FlutterWebAuth2.authenticate result: $result');
      } catch (e) {
        print('CalendlyService: Error during FlutterWebAuth2.authenticate: $e');
        throw Exception('Failed during FlutterWebAuth2.authenticate: $e');
      }
      
      // Extract the authorization code from the result
      final Uri resultUri = Uri.parse(result);
      print('CalendlyService: Parsed resultUri: ${resultUri.toString()}');
      final String? code = resultUri.queryParameters['code'];
      print('CalendlyService: Extracted code: $code');
      
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
            'code_verifier': codeVerifier, // PKCE: Added code_verifier
          },
        );
        
        if (tokenResponse.statusCode == 200) {
          final tokenData = jsonDecode(tokenResponse.body);
          final accessToken = tokenData['access_token'];
          
          // Save token to Firestore (without selecting a specific event type yet)
          await saveCalendlyToken(accessToken);
          
          // Return the token for further use
          return accessToken;
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
  
  // Connect to a specific calendar/event type for a user who already has a token
  Future<void> selectCalendlyEventType(String eventTypeUri) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      
      // Get existing token
      final token = await _getCalendlyToken(userId);
      if (token == null) throw Exception('Calendly not connected');
      
      // Verify the event type exists and is active
      final eventTypes = await getTrainerEventTypes(userId);
      final selectedType = eventTypes.firstWhere(
        (type) => type['uri'] == eventTypeUri,
        orElse: () => {},
      );
      
      if (selectedType.isEmpty) {
        throw Exception('Event type not found');
      }
      
      if (selectedType['active'] != true) {
        throw Exception('Cannot select inactive event type. Please activate it in Calendly first.');
      }
      
      // Update the user document with the selected event type
      await _firestore.collection('users').doc(userId).update({
        'selectedCalendlyEventType': eventTypeUri,
      });
    } catch (e) {
      print('Error selecting Calendly event type: $e');
      throw Exception('Failed to select Calendly event type: $e');
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
        print('CalendlyService: getTrainerEventTypes - No token for trainerId: $trainerId');
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      final uri = await getTrainerCalendlyUri(trainerId);
      if (uri == null) {
        print('CalendlyService: getTrainerEventTypes - No calendlyUri for trainerId: $trainerId');
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      final eventTypesUrl = '$_baseUrl$_eventTypesPath?user=$uri';
      print('CalendlyService: getTrainerEventTypes - Requesting URL: $eventTypesUrl');
      
      final response = await http.get(
        Uri.parse(eventTypesUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      print('CalendlyService: getTrainerEventTypes - Response status: ${response.statusCode}');
      print('CalendlyService: getTrainerEventTypes - Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Map<String, dynamic>> eventTypesList = List<Map<String, dynamic>>.from(data['collection']);
        print('CalendlyService: getTrainerEventTypes - Parsed event types list: $eventTypesList');
        return eventTypesList;
      } else {
        print('CalendlyService: getTrainerEventTypes - Failed to get event types: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to get event types: ${response.statusCode}');
      }
    } catch (e) {
      print('CalendlyService: getTrainerEventTypes - Error: $e');
      throw Exception('Failed to get trainer event types: $e');
    }
  }
  
  // Get available time slots from Calendly for a specific trainer
  Future<List<Map<String, dynamic>>> getTrainerAvailability(String trainerId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final token = await _getCalendlyToken(trainerId);
      if (token == null) {
        print('CalendlyService: getTrainerAvailability - No token for trainerId: $trainerId');
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      // First try to get the selected event type
      final doc = await _firestore.collection('users').doc(trainerId).get();
      final data = doc.data();
      final selectedEventTypeUri = data?['selectedCalendlyEventType'] as String?;
      
      String eventTypeUri;
      
      if (selectedEventTypeUri != null) {
        print('CalendlyService: getTrainerAvailability - Using selected event type: $selectedEventTypeUri');
        eventTypeUri = selectedEventTypeUri;
      } else {
        // Fallback to getting first event type
        print('CalendlyService: getTrainerAvailability - No selected event type, fetching all event types');
        final eventTypes = await getTrainerEventTypes(trainerId);
        
        if (eventTypes.isEmpty) {
          print('CalendlyService: getTrainerAvailability - Trainer has no event types configured.');
          throw Exception('Trainer has no event types configured');
        }
        
        // Find the first active event type
        final activeEventTypes = eventTypes.where((type) => type['active'] == true).toList();
        if (activeEventTypes.isEmpty) {
          print('CalendlyService: getTrainerAvailability - Trainer has no active event types');
          throw Exception('Trainer has no active event types');
        }
        
        // Use the first active event type
        eventTypeUri = activeEventTypes[0]['uri'];
        final eventName = activeEventTypes[0]['name'] ?? 'Unknown Event Type';
        print('CalendlyService: getTrainerAvailability - Using event type: "$eventName" with URI: $eventTypeUri');
      }
      
      // Set date range (default to current time + 1 hour for start, and 7 days after that for end)
      // This ensures start_time is always in the future as required by Calendly
      final now = DateTime.now();
      final start = startDate ?? now.add(const Duration(hours: 1));
      
      // Enforce max 7-day window as per Calendly's API limits
      final maxEndDate = start.add(const Duration(days: 7));
      final end = endDate != null 
          ? (endDate.difference(start).inDays > 7 ? maxEndDate : endDate)
          : maxEndDate;
      
      // Ensure start is actually in the future
      final adjustedStart = start.isBefore(now.add(const Duration(minutes: 30))) 
          ? now.add(const Duration(hours: 1)) 
          : start;
          
      // Format dates for Calendly API - ensure proper ISO format with Z timezone indicator
      final startTime = adjustedStart.toUtc().toIso8601String();
      final endTime = end.toUtc().toIso8601String();

      print('CalendlyService: getTrainerAvailability sending startTime: $startTime');
      print('CalendlyService: getTrainerAvailability sending endTime: $endTime');
      
      // Call API to get available times
      final response = await http.get(
        Uri.parse('$_baseUrl$_availabilityPath?event_type=$eventTypeUri&start_time=$startTime&end_time=$endTime'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      print('CalendlyService: getTrainerAvailability - Response status: ${response.statusCode}');
      print('CalendlyService: getTrainerAvailability - Response preview: ${response.body.substring(0, min(200, response.body.length))}...');
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          if (!data.containsKey('collection')) {
            print('CalendlyService: getTrainerAvailability - Response missing collection key: ${response.body}');
            throw Exception('Invalid response format: missing collection');
          }
          
          // Transform into our expected format
          final List<Map<String, dynamic>> availableTimes = [];
          
          for (final slot in List<Map<String, dynamic>>.from(data['collection'])) {
            try {
              final startTime = DateTime.parse(slot['start_time']);
              
              // For event_type_available_times, the end_time may not be included in the response
              // Calculate it based on the event type duration if not provided
              DateTime endTime;
              if (slot.containsKey('end_time') && slot['end_time'] != null) {
                endTime = DateTime.parse(slot['end_time']);
              } else {
                // Default to 30-minute slots if no end_time is provided
                // This is a common default in Calendly, but ideally we should get the duration from the event type
                endTime = startTime.add(const Duration(minutes: 30));
              }
              
              availableTimes.add({
                'start_time': startTime,
                'end_time': endTime,
                'status': slot['status'] ?? 'available',
                'scheduling_url': slot['scheduling_url'],
                'spot_number': slot['invitees_remaining'] ?? 1,
              });
            } catch (slotError) {
              print('CalendlyService: getTrainerAvailability - Error parsing slot: $slotError, slot data: $slot');
              // Skip this slot and continue with others
            }
          }
          
          print('CalendlyService: getTrainerAvailability - Successfully parsed ${availableTimes.length} available time slots');
          return availableTimes;
        } catch (parseError) {
          print('CalendlyService: getTrainerAvailability - Error parsing response: $parseError');
          print('CalendlyService: getTrainerAvailability - Response body: ${response.body}');
          throw Exception('Failed to parse availability response: $parseError');
        }
      } else {
        print('CalendlyService: getTrainerAvailability - Error response: ${response.body}');
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