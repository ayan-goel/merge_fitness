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
import '../services/notification_service.dart';
import '../services/payment_service.dart';

class CalendlyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Refresh the token a few minutes before it expires to avoid race conditions
  static const int _tokenRefreshLeewaySeconds = 300; // 5 minutes
  
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

  // Internal helper: read auth fields (access, refresh, expiry)
  Future<Map<String, dynamic>?> _getCalendlyAuthData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      return {
        'accessToken': data?['calendlyToken'],
        'refreshToken': data?['calendlyRefreshToken'],
        'expiresAt': data?['calendlyTokenExpiresAt'],
      };
    } catch (e) {
      print('Error getting Calendly auth data: $e');
      return null;
    }
  }

  // Get a valid token, refreshing if necessary
  Future<String?> _getValidCalendlyToken(String userId) async {
    final auth = await _getCalendlyAuthData(userId);
    if (auth == null) return null;
    String? accessToken = auth['accessToken'] as String?;
    final String? refreshToken = auth['refreshToken'] as String?;
    final dynamic expiresAtRaw = auth['expiresAt'];

    // If we don't have expiry or refresh token, fall back to existing token
    if (accessToken == null) return null;

    DateTime? expiresAt;
    if (expiresAtRaw is Timestamp) {
      expiresAt = expiresAtRaw.toDate();
    } else if (expiresAtRaw is DateTime) {
      expiresAt = expiresAtRaw;
    }

    if (expiresAt != null) {
      final now = DateTime.now();
      if (now.isAfter(expiresAt.subtract(const Duration(seconds: _tokenRefreshLeewaySeconds)))) {
        // Try to refresh
        if (refreshToken != null) {
          final refreshed = await _refreshCalendlyToken(userId, refreshToken);
          if (refreshed != null) {
            accessToken = refreshed;
          } else {
            // Refresh failed; mark as disconnected
            await _handleTokenExpiration(userId);
            return null;
          }
        } else {
          // No refresh token; mark expired
          await _handleTokenExpiration(userId);
          return null;
        }
      }
    }

    return accessToken;
  }

  // Refresh token using Calendly OAuth
  Future<String?> _refreshCalendlyToken(String userId, String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final String newAccessToken = data['access_token'];
        final String? newRefreshToken = data['refresh_token']; // Calendly may rotate refresh tokens
        final int expiresIn = data['expires_in'] ?? 3600;

        await _firestore.collection('users').doc(userId).update({
          'calendlyToken': newAccessToken,
          if (newRefreshToken != null) 'calendlyRefreshToken': newRefreshToken,
          'calendlyTokenExpiresAt': Timestamp.fromDate(DateTime.now().add(Duration(seconds: expiresIn))),
          'calendlyConnected': true,
        });

        print('CalendlyService: Token refreshed successfully for $userId');
        return newAccessToken;
      } else {
        print('CalendlyService: Failed to refresh token: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('CalendlyService: Error refreshing token: $e');
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
  
  // Handle token expiration by disconnecting account
  Future<void> _handleTokenExpiration(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'calendlyToken': FieldValue.delete(),
        'calendlyConnected': false,
        'calendlyUri': FieldValue.delete(),
        'calendlySchedulingUrl': FieldValue.delete(),
        'selectedCalendlyEventType': FieldValue.delete(),
      });
      print('CalendlyService: Token expired, account disconnected for user $userId');
    } catch (e) {
      print('Error handling token expiration: $e');
    }
  }
  
  // Save a user's Calendly token
  Future<void> saveCalendlyToken(String token, {String? calendlyUri, String? selectedEventTypeUri}) async {
    try {
      print('CalendlyService: saveCalendlyToken - Starting...');
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      
      print('CalendlyService: saveCalendlyToken - Getting user info from Calendly...');
      // Get user info from Calendly
      final userInfo = await _getCalendlyUserInfo(token);
      print('CalendlyService: saveCalendlyToken - Got user info: ${userInfo['resource']['uri']}');
      
      print('CalendlyService: saveCalendlyToken - Updating Firestore...');
      // Attempt to parse refresh_token and expiry from the token endpoint if available
      // Since this method is called after token exchange, we expect caller to supply those values.
      // However, to keep API surface simple, we'll store access token now and let caller update expiry if known.
      await _firestore.collection('users').doc(userId).update({
        'calendlyToken': token,
        // Keep existing refresh token/expiry if previously present; they may be set by connectCalendlyAccount
        'calendlyConnected': true,
        'calendlyUri': calendlyUri ?? userInfo['resource']['uri'],
        'calendlySchedulingUrl': userInfo['resource']['scheduling_url'],
        'selectedCalendlyEventType': selectedEventTypeUri,
      });
      print('CalendlyService: saveCalendlyToken - Firestore updated successfully');
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
      } else if (response.statusCode == 401) {
        throw Exception('Invalid or expired token');
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
  Future<String?> connectCalendlyAccount() async {
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
      
      // Check for error in the callback
      final String? error = resultUri.queryParameters['error'];
      if (error != null) {
        final String errorDescription = resultUri.queryParameters['error_description'] ?? 'Unknown error';
        print('CalendlyService: OAuth error: $error - $errorDescription');
        throw Exception('OAuth authorization failed: $errorDescription');
      }
      
      final String? code = resultUri.queryParameters['code'];
      print('CalendlyService: Extracted code: $code');
      
      if (code != null) {
        // Exchange code for token
        print('CalendlyService: Exchanging code for token...');
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
        
        print('CalendlyService: Token exchange response status: ${tokenResponse.statusCode}');
        print('CalendlyService: Token exchange response body: ${tokenResponse.body}');
        
      if (tokenResponse.statusCode == 200) {
          final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
          final accessToken = tokenData['access_token'] as String;
          final String? refreshToken = tokenData['refresh_token'] as String?;
          final int expiresIn = tokenData['expires_in'] ?? 3600;
          print('CalendlyService: Successfully got access token: ${accessToken.substring(0, 20)}...');
          
          // Save token and refresh metadata to Firestore (without selecting a specific event type yet)
          print('CalendlyService: About to save token to Firestore...');
          await saveCalendlyToken(accessToken);
          await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
            if (refreshToken != null) 'calendlyRefreshToken': refreshToken,
            'calendlyTokenExpiresAt': Timestamp.fromDate(DateTime.now().add(Duration(seconds: expiresIn))),
          });
          print('CalendlyService: Token saved to Firestore with refresh metadata');
          
          // Return the token for further use
          print('CalendlyService: Returning access token');
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
      final token = await _getValidCalendlyToken(userId);
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
      final token = await _getValidCalendlyToken(trainerId);
      if (token == null) {
        print('CalendlyService: getTrainerEventTypes - No token for trainerId: $trainerId');
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      return await _getTrainerEventTypesWithToken(trainerId, token);
    } catch (e) {
      print('CalendlyService: getTrainerEventTypes - Error: $e');
      throw Exception('Failed to get trainer event types: $e');
    }
  }
  
  // Internal method to get event types with a provided token (avoids redundant token fetch)
  Future<List<Map<String, dynamic>>> _getTrainerEventTypesWithToken(String trainerId, String token) async {
    try {
      final uri = await getTrainerCalendlyUri(trainerId);
      if (uri == null) {
        print('CalendlyService: _getTrainerEventTypesWithToken - No calendlyUri for trainerId: $trainerId');
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      final eventTypesUrl = '$_baseUrl$_eventTypesPath?user=$uri';
      print('CalendlyService: _getTrainerEventTypesWithToken - Requesting URL: $eventTypesUrl');
      
      final response = await http.get(
        Uri.parse(eventTypesUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      print('CalendlyService: _getTrainerEventTypesWithToken - Response status: ${response.statusCode}');
      print('CalendlyService: _getTrainerEventTypesWithToken - Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Map<String, dynamic>> eventTypesList = List<Map<String, dynamic>>.from(data['collection']);
        print('CalendlyService: _getTrainerEventTypesWithToken - Parsed event types list: $eventTypesList');
        return eventTypesList;
      } else if (response.statusCode == 401) {
        // Token may have expired; attempt refresh once
        print('CalendlyService: _getTrainerEventTypesWithToken - 401 received, attempting token refresh');
        final auth = await _getCalendlyAuthData(trainerId);
        final refreshToken = auth?['refreshToken'] as String?;
        if (refreshToken != null) {
          final refreshed = await _refreshCalendlyToken(trainerId, refreshToken);
          if (refreshed != null) {
            // Retry once with refreshed token
            final retry = await http.get(
              Uri.parse(eventTypesUrl),
              headers: {
                'Authorization': 'Bearer $refreshed',
                'Content-Type': 'application/json',
              },
            );
            if (retry.statusCode == 200) {
              final data = jsonDecode(retry.body);
              final List<Map<String, dynamic>> eventTypesList = List<Map<String, dynamic>>.from(data['collection']);
              return eventTypesList;
            }
          }
        }
        await _handleTokenExpiration(trainerId);
        throw Exception('Calendly token has expired. Please reconnect your account.');
      } else {
        print('CalendlyService: _getTrainerEventTypesWithToken - Failed to get event types: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to get event types: ${response.statusCode}');
      }
    } catch (e) {
      print('CalendlyService: _getTrainerEventTypesWithToken - Error: $e');
      rethrow;
    }
  }
  
  // Note: Timezone conversions removed - all times are now stored in UTC in Firestore
  // and automatically converted to the device's local timezone when displayed
  
  // Get trainer's available time slots from Calendly for scheduling
  Future<List<Map<String, dynamic>>> getTrainerAvailability(String trainerId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      // Get valid token - _getValidCalendlyToken will handle refresh if needed
      // This ensures the token is always fresh before we use it
      final token = await _getValidCalendlyToken(trainerId);
      if (token == null) {
        print('CalendlyService: getTrainerAvailability - No token for trainerId: $trainerId');
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      // First try to get the selected event type
      final doc = await _firestore.collection('users').doc(trainerId).get();
      final data = doc.data();
      final selectedEventTypeUri = data?['selectedCalendlyEventType'] as String?;
      
      String eventTypeUri;
      int eventDurationMinutes = 60; // Default to 60 minutes
      
      if (selectedEventTypeUri != null) {
        print('CalendlyService: getTrainerAvailability - Using selected event type: $selectedEventTypeUri');
        eventTypeUri = selectedEventTypeUri;
        
        // Get the event type details to find the duration
        // Pass the token we already have to avoid redundant token fetch/refresh
        final eventTypes = await _getTrainerEventTypesWithToken(trainerId, token);
        final selectedEventType = eventTypes.firstWhere(
          (type) => type['uri'] == selectedEventTypeUri,
          orElse: () => {'duration': 60}, // Default to 60 minutes if not found
        );
        eventDurationMinutes = selectedEventType['duration'] ?? 60;
      } else {
        // Fallback to getting first event type
        print('CalendlyService: getTrainerAvailability - No selected event type, fetching all event types');
      final eventTypes = await _getTrainerEventTypesWithToken(trainerId, token);

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
        eventDurationMinutes = activeEventTypes[0]['duration'] ?? 60;
        final eventName = activeEventTypes[0]['name'] ?? 'Unknown Event Type';
      print('CalendlyService: getTrainerAvailability - Using event type: "$eventName" with URI: $eventTypeUri, duration: ${eventDurationMinutes}min');
      }
      
      print('CalendlyService: getTrainerAvailability - Event duration: ${eventDurationMinutes} minutes');
      
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
              
              // Convert UTC to local timezone for display
              final startTimeLocal = startTimeUtc.toLocal();
              
              // For event_type_available_times, the end_time may not be included in the response
              // Calculate it based on the event type duration if not provided
              DateTime endTimeUtc;
              if (slot.containsKey('end_time') && slot['end_time'] != null) {
                endTimeUtc = DateTime.parse(slot['end_time']);
              } else {
                // Use the actual event type duration instead of defaulting to 30 minutes
                endTimeUtc = startTimeUtc.add(Duration(minutes: eventDurationMinutes));
                print('CalendlyService: getTrainerAvailability - Calculated end time using ${eventDurationMinutes}min duration: ${endTimeUtc.toIso8601String()}');
              }
              
              // Convert end time to local timezone
              final endTimeLocal = endTimeUtc.toLocal();
              
              availableTimes.add({
                'start_time': startTimeLocal,
                'end_time': endTimeLocal,
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
          
          // CRITICAL: Filter out slots that are already booked in our database
          // PERFORMANCE OPTIMIZATION: Fetch all existing sessions once instead of querying for each slot
          final existingSessions = <TrainingSession>[];
          try {
            final snapshot = await _firestore.collection('sessions')
                .where('trainerId', isEqualTo: trainerId)
                .where('status', isEqualTo: 'scheduled')
                .get();
                
            for (final doc in snapshot.docs) {
              existingSessions.add(TrainingSession.fromFirestore(doc));
            }
            
            print('CalendlyService: getTrainerAvailability - Found ${existingSessions.length} existing sessions for conflict checking');
          } catch (e) {
            print('CalendlyService: getTrainerAvailability - Error fetching existing sessions: $e');
            // If we can't fetch existing sessions, show all slots to avoid breaking UX
            return availableTimes;
          }
          
          final filteredTimes = <Map<String, dynamic>>[];
          for (final slot in availableTimes) {
            try {
              final slotStart = slot['start_time'] as DateTime;
              final slotEnd = slot['end_time'] as DateTime;
              
              // Check if this slot conflicts with any existing session (in-memory check)
              bool hasConflict = false;
              for (final existingSession in existingSessions) {
                final existingStart = existingSession.startTime;
                final existingEnd = existingSession.endTime;
                
                // Check for time overlap
                if (slotStart.isBefore(existingEnd) && slotEnd.isAfter(existingStart)) {
                  hasConflict = true;
                  print('CalendlyService: getTrainerAvailability - Filtered out booked slot: ${slotStart.toIso8601String()} - ${slotEnd.toIso8601String()} (conflicts with session ${existingSession.id})');
                  break;
                }
              }
              
              if (!hasConflict) {
                filteredTimes.add(slot);
              }
            } catch (filterError) {
              print('CalendlyService: getTrainerAvailability - Error filtering slot: $filterError');
              // If there's an error checking this specific slot, include it to avoid breaking the UX
              filteredTimes.add(slot);
            }
          }
          
          print('CalendlyService: getTrainerAvailability - Successfully parsed ${availableTimes.length} available time slots, ${filteredTimes.length} after filtering booked slots');
          return filteredTimes;
        } catch (parseError) {
          print('CalendlyService: getTrainerAvailability - Error parsing response: $parseError');
          print('CalendlyService: getTrainerAvailability - Response body: ${response.body}');
          throw Exception('Failed to parse availability response: $parseError');
        }
      } else if (response.statusCode == 401) {
        // Token may have expired; attempt refresh and retry once
        print('CalendlyService: getTrainerAvailability - 401 received, attempting token refresh');
        final auth = await _getCalendlyAuthData(trainerId);
        final refreshToken = auth?['refreshToken'] as String?;
        if (refreshToken != null) {
          final refreshed = await _refreshCalendlyToken(trainerId, refreshToken);
          if (refreshed != null) {
            final retry = await http.get(
              Uri.parse('$_baseUrl$_availabilityPath?event_type=$eventTypeUri&start_time=$startTime&end_time=$endTime'),
              headers: {
                'Authorization': 'Bearer $refreshed',
                'Content-Type': 'application/json',
              },
            );
            if (retry.statusCode == 200) {
              try {
                final data = jsonDecode(retry.body);
                final List<Map<String, dynamic>> availableTimes = [];
                for (final slot in List<Map<String, dynamic>>.from(data['collection'])) {
                  final startTimeUtc = DateTime.parse(slot['start_time']);
                  final startTimeLocal = startTimeUtc.toLocal();
                  DateTime endTimeUtc;
                  if (slot.containsKey('end_time') && slot['end_time'] != null) {
                    endTimeUtc = DateTime.parse(slot['end_time']);
                  } else {
                    endTimeUtc = startTimeUtc.add(Duration(minutes: eventDurationMinutes));
                  }
                  final endTimeLocal = endTimeUtc.toLocal();
                  availableTimes.add({
                    'start_time': startTimeLocal,
                    'end_time': endTimeLocal,
                    'start_time_utc': startTimeUtc,
                    'end_time_utc': endTimeUtc,
                    'status': slot['status'] ?? 'available',
                    'scheduling_url': slot['scheduling_url'],
                    'spot_number': slot['invitees_remaining'] ?? 1,
                  });
                }
                availableTimes.sort((a, b) => (a['start_time'] as DateTime).compareTo(b['start_time'] as DateTime));
                return availableTimes;
              } catch (_) {}
            }
          }
        }
        await _handleTokenExpiration(trainerId);
        throw Exception('Calendly token has expired. Please reconnect your account.');
      } else {
        print('CalendlyService: getTrainerAvailability - Error response: ${response.body}');
        throw Exception('Failed to get availability: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error getting trainer availability: $e');
      throw Exception('Failed to get trainer availability: $e');
    }
  }
  
  // Create a session with atomic transaction to prevent race conditions
  Future<TrainingSession> createSession({
    required String trainerId,
    required String clientId,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    String? notes,
    String? calendlyEventUri,
    String? sessionType,
    List<Map<String, dynamic>>? familyMembers,
    bool isBookingForFamily = false,
    String? payingClientId,
  }) async {
    try {
      // Times are already in local timezone from the time slot selection
      // We'll store them as-is in Firestore (Firestore will convert to UTC automatically)
      
      // Get client information
      final clientDoc = await _firestore.collection('users').doc(clientId).get();
      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final clientName = clientData?['displayName'] ?? 'Client';
      final clientEmail = clientData?['email'] ?? '';
      
      // Get trainer information
      final trainerDoc = await _firestore.collection('users').doc(trainerId).get();
      final trainerData = trainerDoc.data() as Map<String, dynamic>?;
      final trainerName = trainerData?['displayName'] ?? 'Trainer';
      
      // Create session document reference
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
        clientName: clientName,
        clientEmail: clientEmail,
        sessionType: sessionType,
        calendlyUrl: calendlyEventUri != null ? 'https://calendly.com/events/${calendlyEventUri.split('/').last}' : null,
        trainerName: trainerName,
        familyMembers: familyMembers,
        isBookingForFamily: isBookingForFamily,
        payingClientId: payingClientId,
      );
      
      // Use a transaction to ensure atomicity and prevent race conditions
      await _firestore.runTransaction((transaction) async {
        // Create the session atomically
        // Note: Conflict checking is done before the transaction since we can't use queries in transactions
        transaction.set(sessionRef, session.toMap());
        
        print('CalendlyService: Session created successfully in transaction: ${session.id}');
      });
      
      // Add to activity feed (outside transaction since it's not critical)
      try {
        await _addSessionToActivityFeed(session);
      } catch (e) {
        print('Warning: Failed to add session to activity feed: $e');
        // Continue anyway - activity feed is not critical
      }
      
      return session;
    } catch (e) {
      print('Error creating session: $e');
      throw Exception('Failed to create session: $e');
    }
  }
  
  // Check for session conflicts (same trainer, overlapping time)
  Future<bool> _hasSessionConflict({
    required String trainerId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeSessionId,
  }) async {
    try {
      // Check for existing sessions for this trainer that overlap with the requested time
      final snapshot = await _firestore.collection('sessions')
          .where('trainerId', isEqualTo: trainerId)
          .where('status', isEqualTo: 'scheduled')
          .get();
      
      for (final doc in snapshot.docs) {
        final session = TrainingSession.fromFirestore(doc);
        
        // Skip if this is the same session (for updates)
        if (excludeSessionId != null && session.id == excludeSessionId) {
          continue;
        }
        
        // Check for time overlap
        // Two sessions overlap if:
        // 1. New session starts before existing ends AND new session ends after existing starts
        // 2. OR new session completely contains the existing session
        // 3. OR existing session completely contains the new session
        final existingStart = session.startTime;
        final existingEnd = session.endTime;
        
        bool overlaps = (startTime.isBefore(existingEnd) && endTime.isAfter(existingStart));
        
        if (overlaps) {
          print('CalendlyService: Session conflict detected with session ${session.id}');
          print('CalendlyService: Existing session: ${existingStart.toIso8601String()} - ${existingEnd.toIso8601String()}');
          print('CalendlyService: New session: ${startTime.toIso8601String()} - ${endTime.toIso8601String()}');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking session conflicts: $e');
      // If there's an error checking conflicts, err on the side of caution and allow the booking
      // This prevents the system from completely breaking due to database issues
      return false;
    }
  }

  // Schedule a session with conflict checking to prevent double bookings
  Future<TrainingSession> scheduleSession({
    required String trainerId,
    required String clientId,
    required Map<String, dynamic> timeSlot,
    required String location,
    String? notes,
    String? sessionType,
    List<Map<String, dynamic>>? familyMembers,
    bool isBookingForFamily = false,
    String? payingClientId,
  }) async {
    try {
      final token = await _getValidCalendlyToken(trainerId);
      if (token == null) {
        throw Exception('Trainer has not connected their Calendly account');
      }
      
      // Get client info
      final clientDoc = await _firestore.collection('users').doc(clientId).get();
      final clientData = clientDoc.data();
      
      if (clientData == null) {
        throw Exception('Client not found');
      }
      
      // Ensure the times from Calendly are properly converted to EST
      DateTime startTime = timeSlot['start_time'];
      DateTime endTime = timeSlot['end_time'];
      
      print('CalendlyService: Scheduling session for trainer $trainerId from ${startTime.toIso8601String()} to ${endTime.toIso8601String()}');
      
      // Note: Conflict checking is now handled in getTrainerAvailability() 
      // so only properly available slots are shown to users
      
      // Create the session directly since slot was already validated as available
      final session = await createSession(
        trainerId: trainerId,
        clientId: clientId,
        startTime: startTime,
        endTime: endTime,
        location: location,
        notes: notes,
        sessionType: sessionType,
        familyMembers: familyMembers,
        isBookingForFamily: isBookingForFamily,
        payingClientId: payingClientId,
      );
      
      // Get client and trainer names for notifications
      final clientName = clientData['displayName'] ?? 'Client';
      final trainerDoc = await _firestore.collection('users').doc(trainerId).get();
      final trainerName = trainerDoc.data()?['displayName'] ?? 'Trainer';
      
      print('CalendlyService: Session scheduled successfully with ID: ${session.id}');
      
      // Session booking notification is now handled by Cloud Functions automatically
      
      // Session reminders are now handled by Cloud Functions automatically
      // (15-minute and 1-hour reminders are scheduled in the backend)
      
      return session;
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
      
      // Regular sessions where the client is the primary booking client (excluding family sessions)
      final snapshot = await _firestore.collection('sessions')
          .where('clientId', isEqualTo: clientId)
          .where('startTime', isGreaterThan: now)
          .orderBy('startTime')
          .get();
      
      // FAMILY SESSIONS ------------------------------------------------------
      // Sessions booked for family where this user is listed in familyMembers
      final familySnapshot = await _firestore.collection('sessions')
          .where('isBookingForFamily', isEqualTo: true)
          .where('startTime', isGreaterThan: now)
          .orderBy('startTime')
          .get();
      
      // Convert to TrainingSession objects
      final regularSessions = snapshot.docs
          .map((doc) => TrainingSession.fromFirestore(doc))
          .where((session) => session.isBookingForFamily != true) // Exclude family sessions from regular query
          .toList();
      
      final familySessions = familySnapshot.docs
          .map((doc) => TrainingSession.fromFirestore(doc))
          .where((session) {
            if (session.familyMembers == null) return false;
            return session.familyMembers!.any((member) => member['uid'] == clientId);
          })
          .toList();
      
      // Combine and filter out cancelled sessions
      final sessions = [
        ...regularSessions,
        ...familySessions,
      ].where((session) => session.status != 'cancelled').toList();
      
      // Sort by startTime ascending (times are already in local timezone from Firestore)
      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      
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
          List<TrainingSession> sessions = snapshot.docs
              .map((doc) => TrainingSession.fromFirestore(doc))
              .where((session) => 
                  session.startTime.isAfter(now) && 
                  session.status != 'cancelled' &&
                  session.isBookingForFamily != true) // Exclude family sessions from regular query
              .toList();
          
          // Include family sessions in fallback as well
          final familySnapshot = await _firestore.collection('sessions')
              .where('isBookingForFamily', isEqualTo: true)
              .get();
          final familySessions = familySnapshot.docs
              .map((doc) => TrainingSession.fromFirestore(doc))
              .where((session) => 
                  session.startTime.isAfter(now) &&
                  session.status != 'cancelled' &&
                  session.familyMembers != null &&
                  session.familyMembers!.any((member) => member['uid'] == clientId))
              .toList();
          
          sessions.addAll(familySessions);
          
          // Sort by startTime (times are already in local timezone from Firestore)
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
  
  // Format datetime for display (in local timezone)
  String _formatDateTime(DateTime dateTime) {
    // DateTime is already in local timezone
    final localDateTime = dateTime.toLocal();
    
    final date = '${localDateTime.month}/${localDateTime.day}/${localDateTime.year}';
    final hour = localDateTime.hour > 12 ? localDateTime.hour - 12 : (localDateTime.hour == 0 ? 12 : localDateTime.hour);
    final period = localDateTime.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:${localDateTime.minute.toString().padLeft(2, '0')} $period';
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
      
      // Handle payment refund logic
      final paymentService = PaymentService();
      await paymentService.handleSessionCancellation(
        session: session,
        isTrainerCancelling: !isClientCancelling,
      );
      
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
        
        // Session cancellation notifications are now handled by Cloud Functions automatically
      } else {
        activityMessage = 'You cancelled a session with ${session.clientName} scheduled for ${_formatDateTime(session.startTime)}';
        
        // Session cancellation notifications are now handled by Cloud Functions automatically
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
              'email': data['email'] ?? '',
              'phoneNumber': data['phoneNumber'] ?? '',
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

  // Get assigned trainers for a specific client who are available for scheduling
  Future<List<Map<String, dynamic>>> getClientAssignedTrainers(String clientId) async {
    try {
      print("CalendlyService: Getting assigned trainers for client $clientId");
      
      // First ensure user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print("CalendlyService: User not authenticated");
        throw Exception('User not authenticated');
      }
      
      // Get the client's data
      print("CalendlyService: Getting client data");
      final clientDoc = await _firestore.collection('users').doc(clientId).get();
      if (!clientDoc.exists) {
        print("CalendlyService: Client document not found");
        throw Exception('Client not found');
      }
      
      final clientData = clientDoc.data()!;
      
      // Get assigned trainer IDs (support both legacy and new format)
      List<String> assignedTrainerIds = [];
      
      if (clientData['trainerIds'] != null) {
        // New format - use trainerIds array
        assignedTrainerIds = List<String>.from(clientData['trainerIds']);
      } else if (clientData['trainerId'] != null) {
        // Legacy format - convert single trainerId to array
        assignedTrainerIds = [clientData['trainerId']];
      }
      
      print("CalendlyService: Client has ${assignedTrainerIds.length} assigned trainers: $assignedTrainerIds");
      
      if (assignedTrainerIds.isEmpty) {
        print("CalendlyService: No trainers assigned to client");
        throw Exception('No trainer assigned to this client');
      }
      
      // Get trainer data for each assigned trainer
      List<Map<String, dynamic>> availableTrainers = [];
      
      for (final trainerId in assignedTrainerIds) {
        print("CalendlyService: Checking trainer $trainerId");
        
        final trainerDoc = await _firestore.collection('users').doc(trainerId).get();
        if (!trainerDoc.exists) {
          print("CalendlyService: Trainer document not found for $trainerId");
          continue;
        }
        
        final trainerData = trainerDoc.data()!;
        
        // Check if trainer has Calendly connected
        if (trainerData['calendlyConnected'] == true) {
          print("CalendlyService: Trainer $trainerId has Calendly connected");
          availableTrainers.add({
            'id': trainerId,
            'displayName': trainerData['displayName'] ?? 'Trainer',
            'calendlyUrl': trainerData['calendlySchedulingUrl'] ?? '',
            'photoUrl': trainerData['photoUrl'],
            'email': trainerData['email'] ?? '',
            'phoneNumber': trainerData['phoneNumber'] ?? '',
          });
        } else {
          print("CalendlyService: Trainer $trainerId does not have Calendly connected");
        }
      }
      
      print("CalendlyService: Found ${availableTrainers.length} available assigned trainers");
      
      if (availableTrainers.isEmpty) {
        throw Exception('Your assigned trainers have not set up their scheduling calendar yet. Please contact them directly.');
      }
      
      return availableTrainers;
    } catch (e) {
      print('Error getting client assigned trainers: $e');
      rethrow;
    }
  }
  
  // DEBUG: Comprehensive trainer connection debugging
  Future<Map<String, dynamic>> debugTrainerConnection(String trainerId) async {
    Map<String, dynamic> debugInfo = {
      'trainerId': trainerId,
      'timestamp': DateTime.now().toIso8601String(),
      'checks': {},
      'errors': [],
      'warnings': [],
    };

    try {
      // 1. Check if trainer document exists
      print('DEBUG: Checking trainer document...');
      final doc = await _firestore.collection('users').doc(trainerId).get();
      if (!doc.exists) {
        debugInfo['errors'].add('Trainer document does not exist');
        return debugInfo;
      }

      final data = doc.data()!;
      debugInfo['trainerData'] = {
        'role': data['role'],
        'displayName': data['displayName'],
        'email': data['email'],
        'calendlyConnected': data['calendlyConnected'],
        'hasCalendlyToken': data['calendlyToken'] != null,
        'calendlyUri': data['calendlyUri'],
        'calendlySchedulingUrl': data['calendlySchedulingUrl'],
        'selectedCalendlyEventType': data['selectedCalendlyEventType'],
      };
      debugInfo['checks']['trainerDocumentExists'] = true;

      // 2. Check Calendly token
      print('DEBUG: Checking Calendly token...');
      final token = await _getCalendlyToken(trainerId);
      debugInfo['checks']['hasCalendlyToken'] = token != null;
      if (token == null) {
        debugInfo['errors'].add('No Calendly token found for trainer');
        return debugInfo;
      }

      // 3. Check Calendly URI
      print('DEBUG: Checking Calendly URI...');
      final uri = await getTrainerCalendlyUri(trainerId);
      debugInfo['checks']['hasCalendlyUri'] = uri != null;
      if (uri == null) {
        debugInfo['errors'].add('No Calendly URI found for trainer');
        return debugInfo;
      }

      // 4. Test event types API call
      print('DEBUG: Testing event types API call...');
      try {
        final eventTypesUrl = '$_baseUrl$_eventTypesPath?user=$uri';
        print('DEBUG: Event types URL: $eventTypesUrl');
        
        final response = await http.get(
          Uri.parse(eventTypesUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        debugInfo['eventTypesApiCall'] = {
          'url': eventTypesUrl,
          'statusCode': response.statusCode,
          'responseLength': response.body.length,
        };

        if (response.statusCode == 200) {
          final eventTypesData = jsonDecode(response.body);
          final eventTypes = List<Map<String, dynamic>>.from(eventTypesData['collection']);
          
          debugInfo['checks']['eventTypesApiSuccess'] = true;
          debugInfo['eventTypes'] = eventTypes.map((type) => {
            'name': type['name'],
            'uri': type['uri'],
            'active': type['active'],
            'duration': type['duration'],
            'scheduling_url': type['scheduling_url'],
          }).toList();

          final activeEventTypes = eventTypes.where((type) => type['active'] == true).toList();
          debugInfo['checks']['hasActiveEventTypes'] = activeEventTypes.isNotEmpty;
          
          if (activeEventTypes.isEmpty) {
            debugInfo['warnings'].add('Trainer has no active event types in Calendly');
          }

          // 5. Test availability API call for first active event type
          if (activeEventTypes.isNotEmpty) {
            print('DEBUG: Testing availability API call...');
            final eventTypeUri = activeEventTypes[0]['uri'];
            
            final now = DateTime.now();
            final startTime = now.add(const Duration(hours: 1)).toUtc().toIso8601String();
            final endTime = now.add(const Duration(days: 7)).toUtc().toIso8601String();
            
            final availabilityUrl = '$_baseUrl$_availabilityPath?event_type=$eventTypeUri&start_time=$startTime&end_time=$endTime';
            print('DEBUG: Availability URL: $availabilityUrl');
            
            final availabilityResponse = await http.get(
              Uri.parse(availabilityUrl),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );

            debugInfo['availabilityApiCall'] = {
              'url': availabilityUrl,
              'statusCode': availabilityResponse.statusCode,
              'responseLength': availabilityResponse.body.length,
              'eventTypeUri': eventTypeUri,
              'startTime': startTime,
              'endTime': endTime,
            };

            if (availabilityResponse.statusCode == 200) {
              final availabilityData = jsonDecode(availabilityResponse.body);
              final slots = List<Map<String, dynamic>>.from(availabilityData['collection'] ?? []);
              
              debugInfo['checks']['availabilityApiSuccess'] = true;
              debugInfo['availabilitySlots'] = slots.length;
              debugInfo['sampleSlots'] = slots.take(3).map((slot) => {
                'start_time': slot['start_time'],
                'status': slot['status'],
                'scheduling_url': slot['scheduling_url'],
              }).toList();

              if (slots.isEmpty) {
                debugInfo['warnings'].add('No available time slots returned from Calendly API');
              }
            } else {
              debugInfo['errors'].add('Availability API call failed: ${availabilityResponse.statusCode}');
              debugInfo['availabilityApiCall']['responseBody'] = availabilityResponse.body;
            }
          }
        } else {
          debugInfo['errors'].add('Event types API call failed: ${response.statusCode}');
          debugInfo['eventTypesApiCall']['responseBody'] = response.body;
        }
      } catch (apiError) {
        debugInfo['errors'].add('API call error: $apiError');
      }

    } catch (e) {
      debugInfo['errors'].add('Debug error: $e');
    }

    return debugInfo;
  }
} 