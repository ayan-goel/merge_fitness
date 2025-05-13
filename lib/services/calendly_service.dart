import 'dart:convert';
import 'dart:math'; // For random string generation and min function
import 'package:crypto/crypto.dart'; // For SHA256
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import '../models/session_model.dart';

class CalendlyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Timezone settings for EST
  static const String targetTimeZone = 'America/New_York'; // EST timezone
  
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
  
  // Convert UTC time to Eastern Standard Time
  DateTime _convertToEST(DateTime utcTime) {
    final estTimeZone = tz.getLocation(targetTimeZone);
    final estTime = tz.TZDateTime.from(utcTime, estTimeZone);
    return estTime;
  }
  
  // Convert Eastern Standard Time to UTC
  DateTime _convertToUTC(DateTime estTime) {
    final estTimeZone = tz.getLocation(targetTimeZone);
    final estDateTime = tz.TZDateTime(estTimeZone, 
        estTime.year, estTime.month, estTime.day, 
        estTime.hour, estTime.minute, estTime.second);
    return estDateTime.toUtc();
  }
  
  // Get trainer's available time slots from Calendly for scheduling
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
              // Parse UTC time from Calendly
              final startTimeUtc = DateTime.parse(slot['start_time']);
              
              // Convert to EST for display
              final startTimeEst = _convertToEST(startTimeUtc);
              
              // For event_type_available_times, the end_time may not be included in the response
              // Calculate it based on the event type duration if not provided
              DateTime endTimeUtc;
              if (slot.containsKey('end_time') && slot['end_time'] != null) {
                endTimeUtc = DateTime.parse(slot['end_time']);
              } else {
                // Default to 30-minute slots if no end_time is provided
                // This is a common default in Calendly, but ideally we should get the duration from the event type
                endTimeUtc = startTimeUtc.add(const Duration(minutes: 30));
              }
              
              // Convert end time to EST
              final endTimeEst = _convertToEST(endTimeUtc);
              
              availableTimes.add({
                'start_time': startTimeEst,
                'end_time': endTimeEst,
                'start_time_utc': startTimeUtc, // Keep original UTC time for reference
                'end_time_utc': endTimeUtc,
                'status': slot['status'] ?? 'available',
                'scheduling_url': slot['scheduling_url'],
                'spot_number': slot['invitees_remaining'] ?? 1,
              });
            } catch (slotError) {
              print('CalendlyService: getTrainerAvailability - Error parsing slot: $slotError, slot data: $slot');
              // Skip this slot and continue with others
            }
          }
          
          // Sort times by EST time, not UTC time
          availableTimes.sort((a, b) => 
            (a['start_time'] as DateTime).compareTo(b['start_time'] as DateTime)
          );
          
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
  
  // Create a session
  Future<TrainingSession> createSession({
    required String trainerId,
    required String clientId,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    String? notes,
    String? calendlyEventUri,
    String? sessionType,
  }) async {
    try {
      // Ensure times are in EST
      final estStartTime = _convertToEST(startTime);
      final estEndTime = _convertToEST(endTime);
      
      // Get client information
      final clientDoc = await _firestore.collection('users').doc(clientId).get();
      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final clientName = clientData?['displayName'] ?? 'Client';
      final clientEmail = clientData?['email'] ?? '';
      
      // Get trainer information
      final trainerDoc = await _firestore.collection('users').doc(trainerId).get();
      final trainerData = trainerDoc.data() as Map<String, dynamic>?;
      final trainerName = trainerData?['displayName'] ?? 'Trainer';
      
      // Create session document
      final sessionRef = _firestore.collection('sessions').doc();
      
      final session = TrainingSession(
        id: sessionRef.id,
        trainerId: trainerId,
        clientId: clientId,
        startTime: estStartTime,
        endTime: estEndTime,
        location: location,
        status: 'scheduled',
        notes: notes,
        calendlyEventUri: calendlyEventUri,
        createdAt: DateTime.now(),
        clientName: clientName,
        clientEmail: clientEmail,
        sessionType: sessionType,
        calendlyUrl: calendlyEventUri != null ? 'https://calendly.com/events/${calendlyEventUri.split('/').last}' : null,
        trainerName: trainerName,
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
    String? sessionType,
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
      // Ensure the times from Calendly are properly converted to EST
      DateTime startTime = timeSlot['start_time'];
      DateTime endTime = timeSlot['end_time'];
      
      return await createSession(
        trainerId: trainerId,
        clientId: clientId,
        startTime: startTime,
        endTime: endTime,
        location: location,
        notes: notes,
        sessionType: sessionType,
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
      
      final sessions = snapshot.docs
          .map((doc) => TrainingSession.fromFirestore(doc))
          .where((session) => session.status != 'cancelled') // Filter out cancelled sessions
          .toList();
      
      // Ensure all times are properly in EST
      for (var session in sessions) {
        if (session.startTime.timeZoneName != targetTimeZone) {
          // Convert start and end times to EST if they're not already
          session.startTime = _convertToEST(session.startTime);
          session.endTime = _convertToEST(session.endTime);
        }
      }
      
      return sessions;
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
              .where((session) => 
                  session.startTime.isAfter(now) && 
                  session.status != 'cancelled') // Filter out cancelled sessions and past sessions
              .toList();
          
          // Ensure all times are properly in EST
          for (var session in sessions) {
            if (session.startTime.timeZoneName != targetTimeZone) {
              // Convert start and end times to EST if they're not already
              session.startTime = _convertToEST(session.startTime);
              session.endTime = _convertToEST(session.endTime);
            }
          }
          
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
  
  // Get upcoming (non-cancelled) sessions for a trainer
  Future<List<TrainingSession>> getTrainerUpcomingSessions(String trainerId) async {
    try {
      final now = DateTime.now();
      
      final snapshot = await _firestore.collection('sessions')
          .where('trainerId', isEqualTo: trainerId)
          .where('startTime', isGreaterThan: now)
          .orderBy('startTime')
          .get();
      
      return snapshot.docs
          .map((doc) => TrainingSession.fromFirestore(doc))
          .where((session) => session.status != 'cancelled') // Filter out cancelled sessions
          .toList();
    } catch (e) {
      print('Error getting trainer upcoming sessions: $e');
      
      // If the error is about indexes building, try an alternative approach
      if (e.toString().contains('index is currently building') || 
          e.toString().contains('requires an index')) {
        try {
          // Get without ordering (works without index)
          final snapshot = await _firestore.collection('sessions')
              .where('trainerId', isEqualTo: trainerId)
              .get();
          
          final now = DateTime.now();
          // Filter and sort manually
          final sessions = snapshot.docs
              .map((doc) => TrainingSession.fromFirestore(doc))
              .where((session) => 
                  session.startTime.isAfter(now) && 
                  session.status != 'cancelled') // Filter out cancelled sessions and past sessions
              .toList();
          
          sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
          return sessions;
        } catch (fallbackError) {
          print('Fallback error getting trainer upcoming sessions: $fallbackError');
          return [];
        }
      }
      return [];
    }
  }
  
  // Format datetime for display
  String _formatDateTime(DateTime dateTime) {
    // Ensure the datetime is in EST
    final estDateTime = _convertToEST(dateTime);
    
    final date = '${estDateTime.month}/${estDateTime.day}/${estDateTime.year}';
    final hour = estDateTime.hour > 12 ? estDateTime.hour - 12 : (estDateTime.hour == 0 ? 12 : estDateTime.hour);
    final period = estDateTime.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:${estDateTime.minute.toString().padLeft(2, '0')} $period';
    return '$date at $time';
  }
  
  // Cancel a training session
  Future<bool> cancelSession(String sessionId, {String? cancellationReason}) async {
    try {
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      
      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }
      
      final session = TrainingSession.fromFirestore(sessionDoc);
      
      // Only allow cancellation if the session is in the future
      if (session.startTime.isBefore(DateTime.now())) {
        throw Exception('Cannot cancel a session that has already started or completed');
      }
      
      // Get current user ID to determine if it's client or trainer cancelling
      final currentUserId = _auth.currentUser?.uid;
      final isClientCancelling = currentUserId == session.clientId;
      
      if (isClientCancelling) {
        // Client cancellation - restricted to only status and notes
        final updatedNotes = cancellationReason != null
            ? '${session.notes ?? ''}\n\nCancellation reason: $cancellationReason'
            : session.notes;
        
        await _firestore.collection('sessions').doc(sessionId).update({
          'status': 'cancelled',
          'notes': updatedNotes,
        });
      } else {
        // Trainer or admin cancellation - can update more fields
        await _firestore.collection('sessions').doc(sessionId).update({
          'status': 'cancelled',
          'notes': cancellationReason != null 
              ? '${session.notes ?? ''}\n\nCancellation reason: $cancellationReason'
              : session.notes,
        });
      }
      
      // Get the name of the user who cancelled (client or trainer)
      String? cancelledByName;
      String activityMessage;
      
      try {
        // Get current user to determine who cancelled
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            cancelledByName = userDoc.data()?['displayName'] ?? 'Unknown user';
          }
        }
      } catch (e) {
        print('Error getting cancellation user info: $e');
        // Continue even if we can't get the user name
      }
      
      // Create appropriate message based on who cancelled
      final isClientCancellation = _auth.currentUser?.uid == session.clientId;
      if (isClientCancellation) {
        activityMessage = '${cancelledByName ?? session.clientName} cancelled a session scheduled for ${_formatDateTime(session.startTime)}';
      } else {
        activityMessage = 'You cancelled a session with ${session.clientName} scheduled for ${_formatDateTime(session.startTime)}';
      }
      
      // Add reason if provided
      if (cancellationReason != null && cancellationReason.isNotEmpty) {
        activityMessage += '\nReason: $cancellationReason';
      }
      
      // Add to activity feed
      await _firestore.collection('activityFeed').add({
        'trainerId': session.trainerId,
        'clientId': session.clientId,
        'type': 'session_cancelled',
        'message': activityMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'relatedId': session.id,
        'cancellationReason': cancellationReason,
        'cancelledBy': _auth.currentUser?.uid,
      });
      
      return true;
    } catch (e) {
      print('Error cancelling session: $e');
      throw Exception('Failed to cancel session: $e');
    }
  }
  
  // Get all available trainers for scheduling
  Future<List<Map<String, dynamic>>> getAvailableTrainers() async {
    try {
      print("CalendlyService: Attempting to get available trainers");
      
      // First ensure user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print("CalendlyService: User not authenticated");
        throw Exception('User not authenticated');
      }
      
      print("CalendlyService: User authenticated as ${currentUser.uid}");
      
      // Simplified query first - just get all trainers
      print("CalendlyService: Querying for all trainers");
      final snapshot = await _firestore.collection('users')
          .where('role', isEqualTo: 'trainer')
          .get();
      
      print("CalendlyService: Found ${snapshot.docs.length} trainers");
      
      // Filter connected trainers in memory
      final trainers = snapshot.docs
          .where((doc) => doc.data()['calendlyConnected'] == true)
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'displayName': data['displayName'] ?? 'Trainer',
              'calendlyUrl': data['calendlySchedulingUrl'] ?? '',
              'photoUrl': data['photoUrl'],
              'specialty': data['specialty'] ?? 'General Fitness',
            };
          }).toList();
      
      print("CalendlyService: Filtered to ${trainers.length} connected trainers");
      return trainers;
    } catch (e) {
      print('Error getting available trainers: $e');
      // Return empty list instead of throwing to avoid UI errors
      return [];
    }
  }
} 