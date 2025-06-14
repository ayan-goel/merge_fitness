import 'dart:io';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/foundation.dart';

// This needs to be added to pubspec.yaml:
// flutter_local_notifications: ^16.3.2

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // For local notifications
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() => _instance;
  
  NotificationService._internal();
  
  // Initialize notifications
  Future<void> init() async {
    // Initialize timezone
    tz_data.initializeTimeZones();
    
    try {
      // Request permission for iOS and web
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      print('User granted permission: ${settings.authorizationStatus}');
      
      // Initialize local notifications only for mobile platforms
      if (!kIsWeb) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
            
        const DarwinInitializationSettings initializationSettingsIOS =
            DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        
        const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
        
        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _onNotificationTap,
        );
        
        // Set up background message handler for mobile platforms
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }
      
      // Set up foreground notification handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle notification when app is opened from terminated state
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
      
      // Handle when app is opened from background state
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      // Get and store FCM token
      try {
        if (kIsWeb) {
          // On web, check if running in secure context (required for service workers)
          if (Uri.base.scheme == 'https' || Uri.base.host == 'localhost') {
            try {
              String? token = await _messaging.getToken();
              if (token != null) {
                await _saveFcmToken(token);
                print('Web FCM token retrieved successfully');
              } else {
                print('No FCM token available for web');
              }
            } catch (e) {
              // Specifically catch and handle service worker errors
              if (e.toString().contains('no active Service Worker')) {
                print('Web push notifications require a production HTTPS environment.');
              } else if (e.toString().contains('permission')) {
                print('Notification permission not granted for web');
              } else {
                print('Error getting web FCM token: $e');
              }
            }
          } else {
            print('Web push notifications are only available in HTTPS or localhost environments');
          }
        } else {
          // Mobile platforms - add more robust error handling
          try {
            // For iOS, handle APNS token availability
            if (Platform.isIOS) {
              await _requestAPNSTokenAndGetFCM();
            } else {
              // Android - direct FCM token request
              String? token = await _messaging.getToken();
              if (token != null) {
                await _saveFcmToken(token);
                print('Mobile FCM token retrieved successfully');
              } else {
                print('No FCM token available for mobile');
              }
            }
          } catch (e) {
            if (e.toString().contains('MISSING_INSTANCEID_SERVICE')) {
              print('Google Play Services not available - FCM not supported');
            } else if (e.toString().contains('SERVICE_NOT_AVAILABLE')) {
              print('FCM service not available on this device');
            } else if (e.toString().contains('apns-token-not-set')) {
              print('APNS token not ready yet - will retry after user authentication');
              // Don't treat this as a critical error - token will be retrieved later
            } else {
              print('Error getting mobile FCM token: $e');
            }
          }
        }
      } catch (e) {
        print('General error in FCM token setup: $e');
        // Continue even if token retrieval fails completely
      }
      
      // Listen for token refresh with error handling
      _messaging.onTokenRefresh.listen((token) {
        _saveFcmToken(token).catchError((error) {
          print('Error handling token refresh: $error');
        });
      });
      
      // Check for any initial notification if app was launched from a notification
      if (!kIsWeb) {
        final NotificationAppLaunchDetails? launchDetails = 
            await _localNotifications.getNotificationAppLaunchDetails();
        
        if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
          // App was launched from a notification
          handleNotificationResponse(launchDetails.notificationResponse?.payload);
        }
      }
    } catch (e) {
      // Handle errors gracefully to prevent app crash
      print('Error initializing notification service: $e');
    }
  }
  
  // Initialize for web without push notifications
  Future<void> initWebWithoutPush() async {
    // Initialize timezone
    tz_data.initializeTimeZones();
    
    // Set up message handlers but skip FCM token retrieval
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification when app is opened from terminated state
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
    
    // Handle when app is opened from background state
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }
  
  // Initialize FCM token after user authentication
  Future<void> initializeFcmTokenAfterAuth() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        if (kIsWeb) {
          // Web platform
          if (Uri.base.scheme == 'https' || Uri.base.host == 'localhost') {
            String? token = await _messaging.getToken();
            if (token != null) {
              await _saveFcmToken(token);
              print('FCM token initialized after auth for web');
            }
          }
        } else {
          // Mobile platforms
          try {
            if (Platform.isIOS) {
              await _requestAPNSTokenAndGetFCM();
            } else {
              String? token = await _messaging.getToken();
              if (token != null) {
                await _saveFcmToken(token);
                print('FCM token initialized after auth for mobile');
              }
            }
          } catch (e) {
            if (e.toString().contains('apns-token-not-set')) {
              print('APNS token still not ready - this is normal on iOS, will retry later');
            } else {
              print('Error getting FCM token after auth: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error initializing FCM token after auth: $e');
    }
  }
  
  // Save FCM token to Firestore for the current user
  Future<void> _saveFcmToken(String token) async {
    try {
    User? user = _auth.currentUser;
    if (user != null) {
        // Check if user document exists first
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (userDoc.exists) {
          // Update existing document
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastActive': FieldValue.serverTimestamp(),
      });
          print('FCM token saved successfully for user: ${user.uid}');
        } else {
          // Create document if it doesn't exist
          await _firestore.collection('users').doc(user.uid).set({
            'fcmTokens': [token],
            'lastActive': FieldValue.serverTimestamp(),
            'email': user.email,
          }, SetOptions(merge: true));
          print('FCM token saved with new document for user: ${user.uid}');
        }
      }
    } catch (e) {
      print('Error saving FCM token: $e');
      // Don't throw the error - continue app execution
    }
  }
  
  // Request APNS token first, then get FCM token (iOS-specific)
  Future<void> _requestAPNSTokenAndGetFCM() async {
    try {
      // First try to get APNS token to ensure it's available
      String? apnsToken = await _messaging.getAPNSToken();
      
      if (apnsToken != null) {
        print('APNS token obtained successfully');
        // Now that APNS token is available, get FCM token
        String? token = await _messaging.getToken();
        if (token != null) {
          await _saveFcmToken(token);
          print('Mobile FCM token retrieved successfully after APNS');
        } else {
          print('No FCM token available even after APNS token');
        }
      } else {
        print('APNS token not available yet - will retry later');
        // Schedule a retry after a short delay
        Timer(const Duration(seconds: 5), () async {
          try {
            String? retryToken = await _messaging.getToken();
            if (retryToken != null) {
              await _saveFcmToken(retryToken);
              print('FCM token retrieved on retry');
            }
          } catch (e) {
            print('Failed to get FCM token on retry: $e');
          }
        });
      }
    } catch (e) {
      print('Error in APNS/FCM token sequence: $e');
      // Still try to get FCM token directly as fallback
      try {
        String? fallbackToken = await _messaging.getToken();
        if (fallbackToken != null) {
          await _saveFcmToken(fallbackToken);
          print('FCM token retrieved via fallback method');
        }
      } catch (fallbackError) {
        print('Fallback FCM token retrieval also failed: $fallbackError');
      }
    }
  }
  
  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');
    
    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      
      // Show a local notification on mobile
      if (!kIsWeb) {
        await _showLocalNotification(
          id: message.hashCode,
          title: message.notification?.title ?? 'Merge Fitness',
          body: message.notification?.body ?? '',
          payload: message.data.toString(),
        );
      }
    }
  }
  
  // Show a local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Only available on mobile platforms
    if (kIsWeb) return;
    
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
      'merge_fitness_channel',
      'Merge Fitness Notifications',
      channelDescription: 'Notifications from Merge Fitness',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await _localNotifications.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
  
  // Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap using the payload
    print('Notification tapped with payload: ${response.payload}');
    handleNotificationResponse(response.payload);
  }
  
  // Handle when a notification opens the app from terminated state
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
    print('Message data: ${message.data}');
    
    // Handle navigation based on message data
    // For example, navigate to a specific screen
  }
  
  // Schedule a local notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    // Only available on mobile platforms
    if (kIsWeb) return;
    
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
      'merge_fitness_channel',
      'Merge Fitness Notifications',
      channelDescription: 'Notifications from Merge Fitness',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        const DarwinNotificationDetails();
    
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }
  
  // Send notification to specific users through FCM (usually done from backend)
  Future<void> sendNotificationToUsers(
    List<String> userIds,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    // This is typically done from a Cloud Function
    // Here we're just demonstrating the concept
    print('Would send notification to users: $userIds');
    print('Title: $title');
    print('Body: $body');
    print('Data: $data');
  }
  
  // Schedule workout reminder notification
  Future<void> scheduleWorkoutReminder(
    String workoutName,
    DateTime scheduledTime,
  ) async {
    // Only available on mobile platforms
    if (kIsWeb) return;
    
    await scheduleNotification(
      id: workoutName.hashCode,
      title: 'Workout Reminder',
      body: 'Time for your $workoutName workout!',
      scheduledTime: scheduledTime,
      payload: 'workout_reminder',
    );
  }
  
  // Schedule session reminder notification
  Future<void> scheduleSessionReminder(
    String trainerName,
    DateTime sessionTime,
  ) async {
    // Only available on mobile platforms
    if (kIsWeb) return;
    
    // Schedule 15 minutes before the session
    DateTime reminderTime = sessionTime.subtract(const Duration(minutes: 15));
    
    await scheduleNotification(
      id: sessionTime.millisecondsSinceEpoch,
      title: 'Session Reminder',
      body: 'Your session with $trainerName is in 15 minutes!',
      scheduledTime: reminderTime,
      payload: 'session_reminder',
    );
  }
  
  // Schedule a reminder 1 hour before a session for clients
  Future<void> scheduleOneHourSessionReminder(
    String trainerName,
    DateTime sessionTime,
  ) async {
    // Only available on mobile platforms
    if (kIsWeb) return;
    
    // Schedule 1 hour before the session
    DateTime reminderTime = sessionTime.subtract(const Duration(hours: 1));
    
    // Only schedule if the reminder time is in the future
    if (reminderTime.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: sessionTime.millisecondsSinceEpoch + 1, // Different ID from 15-min reminder
        title: 'Upcoming Session',
        body: 'You have a session with $trainerName in 1 hour',
        scheduledTime: reminderTime,
        payload: 'session_reminder_1hr',
      );
    }
  }
  
  // Workout check-in reminder at 7pm if not completed
  Future<void> scheduleWorkoutCheckInReminder(
    String workoutId,
    String workoutName,
  ) async {
    // Only available on mobile platforms
    if (kIsWeb) return;
    
    // Schedule for 7pm today
    DateTime now = DateTime.now();
    DateTime reminderTime = DateTime(
      now.year,
      now.month,
      now.day,
      19, // 7pm
      0,
    );
    
    // Only schedule if it's before 7pm
    if (now.isBefore(reminderTime)) {
      await scheduleNotification(
        id: workoutId.hashCode,
        title: 'Workout Check-In',
        body: 'Did you complete your $workoutName workout today?',
        scheduledTime: reminderTime,
        payload: 'workout_checkin:$workoutId',
      );
    }
  }
  
  // Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    // Only available on mobile platforms
    if (kIsWeb) return;
    
    await _localNotifications.cancel(id);
  }
  
  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    // Only available on mobile platforms
    if (kIsWeb) return;
    
    await _localNotifications.cancelAll();
  }
  
  // Check for incomplete workouts and send reminders
  Future<void> checkIncompleteWorkoutsAndNotify() async {
    // Skip for web platform
    if (kIsWeb) return;
    
    // Get current user
    User? user = _auth.currentUser;
    if (user == null) return;

    // Get today's date
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    
    // Check if it's after 7 PM
    bool isAfter7PM = now.hour >= 19;
    
    // If it's already past 7 PM, we'll check and send notifications immediately
    // Otherwise, we'll schedule them for 7 PM
    
    // Query workouts assigned for today that aren't completed
    QuerySnapshot workoutSnapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: user.uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(today.year, today.month, today.day, 23, 59, 59)))
        .get();
    
    for (var doc in workoutSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // Check if workout is not completed
      if (data['completedAt'] == null) {
        String workoutId = doc.id;
        
        // Get workout program info for better notification
        String programId = data['programId'] ?? '';
        String workoutName = 'your workout';
        
        if (programId.isNotEmpty) {
          try {
            DocumentSnapshot programDoc = await _firestore.collection('programs').doc(programId).get();
            if (programDoc.exists) {
              Map<String, dynamic> programData = programDoc.data() as Map<String, dynamic>;
              workoutName = programData['title'] ?? 'your workout';
            }
          } catch (e) {
            print('Error fetching workout program: $e');
          }
        }
        
        if (isAfter7PM) {
          // It's already past 7 PM, send notification now
          await _showLocalNotification(
            id: workoutId.hashCode,
            title: 'Workout Reminder',
            body: 'Don\'t forget to complete $workoutName today!',
            payload: 'workout_reminder:$workoutId',
          );
        } else {
          // Schedule for 7 PM today
          DateTime reminderTime = DateTime(
            today.year,
            today.month,
            today.day,
            19, // 7pm
            0,
          );
          
          await scheduleNotification(
            id: workoutId.hashCode,
            title: 'Workout Reminder',
            body: 'Don\'t forget to complete $workoutName today!',
            scheduledTime: reminderTime,
            payload: 'workout_reminder:$workoutId',
          );
        }
      }
    }
  }
  
  // Set up daily workout reminder check
  Future<void> setupDailyWorkoutReminderCheck() async {
    // Skip for web platform
    if (kIsWeb) return;
    
    // First check for any workouts that need reminders today
    await checkIncompleteWorkoutsAndNotify();
    
    // Then schedule the next check for tomorrow at an earlier time (e.g., 10 AM)
    // This ensures we set up the 7 PM reminder for the next day
    DateTime now = DateTime.now();
    DateTime tomorrow = now.add(const Duration(days: 1));
    DateTime scheduledCheckTime = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      10, // 10 AM
      0,
    );
    
    await scheduleNotification(
      id: 'daily_workout_check'.hashCode,
      title: 'System Update',
      body: 'Updating workout schedule',
      scheduledTime: scheduledCheckTime,
      payload: 'setup_workout_reminders',
    );
  }
  
  // Handle notification payload when app is opened from a notification
  void handleNotificationResponse(String? payload) {
    if (payload == null) return;
    
    print('Handling notification payload: $payload');
    
    // Parse the payload to determine action
    if (payload.startsWith('workout_reminder:') || payload.startsWith('workout_checkin:')) {
      // Extract workout ID from payload
      String workoutId = payload.split(':')[1];
      
      // Navigate to workout details screen
      // Note: Since we can't directly navigate from a service,
      // we'll need to use a stream or global key approach
      // to communicate with the UI
      _notifyWorkoutSelected(workoutId);
    } else if (payload == 'account_approved') {
      // Account was approved - user can now access the app normally
      // The home screen will automatically redirect them to the main app
      print('Account approved notification tapped');
    } else if (payload == 'account_rejected') {
      // Account was rejected - user will see the rejection screen
      print('Account rejected notification tapped');
    } else if (payload == 'setup_workout_reminders') {
      // This is a system notification to set up workout reminders
      setupDailyWorkoutReminderCheck();
    }
  }
  
  // Notification stream for UI to listen to
  final StreamController<String> _workoutStreamController = StreamController<String>.broadcast();
  Stream<String> get workoutSelectedStream => _workoutStreamController.stream;
  
  void _notifyWorkoutSelected(String workoutId) {
    _workoutStreamController.add(workoutId);
  }
  
  void dispose() {
    _workoutStreamController.close();
  }
  
  // Send notification for session cancellation by trainer
  Future<void> sendSessionCancellationNotification(
    String clientId,
    String trainerName,
    DateTime scheduledTime,
    String sessionLocation,
    String? cancellationReason,
  ) async {
    // Skip for web platform
    if (kIsWeb) return;
    
    try {
      // Get client's FCM token(s)
      final clientDoc = await _firestore.collection('users').doc(clientId).get();
      final clientData = clientDoc.data();
      if (clientData == null || !clientData.containsKey('fcmTokens')) {
        print('No FCM tokens found for client: $clientId');
        return;
      }
      
      final List<dynamic> fcmTokens = clientData['fcmTokens'] ?? [];
      if (fcmTokens.isEmpty) {
        print('Empty FCM tokens list for client: $clientId');
        return;
      }
      
      // Format session time for display
      final String sessionTime = _formatSessionTime(scheduledTime);
      
      // Create notification message
      String notificationBody = 'Your session with $trainerName scheduled for $sessionTime has been cancelled';
      if (cancellationReason != null && cancellationReason.isNotEmpty) {
        notificationBody += '. Reason: $cancellationReason';
      }
      
      // Show a local notification
      await _showLocalNotification(
        id: scheduledTime.millisecondsSinceEpoch,
        title: 'Session Cancelled',
        body: notificationBody,
        payload: 'session_cancelled',
      );
    } catch (e) {
      print('Error sending session cancellation notification: $e');
    }
  }
  
  // Send notification for workout completion to trainer
  Future<void> sendWorkoutCompletedNotification(
    String trainerId,
    String clientName,
    String workoutName,
  ) async {
    // Skip for web platform
    if (kIsWeb) return;
    
    try {
      // Get trainer's FCM token(s)
      final trainerDoc = await _firestore.collection('users').doc(trainerId).get();
      final trainerData = trainerDoc.data();
      if (trainerData == null || !trainerData.containsKey('fcmTokens')) {
        print('No FCM tokens found for trainer: $trainerId');
        return;
      }
      
      final List<dynamic> fcmTokens = trainerData['fcmTokens'] ?? [];
      if (fcmTokens.isEmpty) {
        print('Empty FCM tokens list for trainer: $trainerId');
        return;
      }
      
      // Show a local notification
      await _showLocalNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Workout Completed',
        body: '$clientName completed the workout "$workoutName"',
        payload: 'workout_completed',
      );
    } catch (e) {
      print('Error sending workout completion notification: $e');
    }
  }
  
  // Send notification for session booking to trainer
  Future<void> sendSessionBookedNotification(
    String trainerId,
    String clientName,
    DateTime sessionTime,
    String sessionLocation,
  ) async {
    // Skip for web platform
    if (kIsWeb) return;
    
    try {
      // Get trainer's FCM token(s)
      final trainerDoc = await _firestore.collection('users').doc(trainerId).get();
      final trainerData = trainerDoc.data();
      if (trainerData == null || !trainerData.containsKey('fcmTokens')) {
        print('No FCM tokens found for trainer: $trainerId');
        return;
      }
      
      final List<dynamic> fcmTokens = trainerData['fcmTokens'] ?? [];
      if (fcmTokens.isEmpty) {
        print('Empty FCM tokens list for trainer: $trainerId');
        return;
      }
      
      // Format session time for display
      final String formattedTime = _formatSessionTime(sessionTime);
      
      // Show a local notification
      await _showLocalNotification(
        id: sessionTime.millisecondsSinceEpoch,
        title: 'New Session Booked',
        body: '$clientName booked a session for $formattedTime at $sessionLocation',
        payload: 'session_booked',
      );
    } catch (e) {
      print('Error sending session booked notification: $e');
    }
  }
  
  // Send notification for session cancellation by client
  Future<void> sendClientCancelledSessionNotification(
    String trainerId,
    String clientName,
    DateTime scheduledTime,
    String? cancellationReason,
  ) async {
    // Skip for web platform
    if (kIsWeb) return;
    
    try {
      // Get trainer's FCM token(s)
      final trainerDoc = await _firestore.collection('users').doc(trainerId).get();
      final trainerData = trainerDoc.data();
      if (trainerData == null || !trainerData.containsKey('fcmTokens')) {
        print('No FCM tokens found for trainer: $trainerId');
        return;
      }
      
      final List<dynamic> fcmTokens = trainerData['fcmTokens'] ?? [];
      if (fcmTokens.isEmpty) {
        print('Empty FCM tokens list for trainer: $trainerId');
        return;
      }
      
      // Format session time for display
      final String sessionTime = _formatSessionTime(scheduledTime);
      
      // Create notification message
      String notificationBody = '$clientName cancelled their session scheduled for $sessionTime';
      if (cancellationReason != null && cancellationReason.isNotEmpty) {
        notificationBody += '. Reason: $cancellationReason';
      }
      
      // Show a local notification
      await _showLocalNotification(
        id: scheduledTime.millisecondsSinceEpoch,
        title: 'Session Cancelled',
        body: notificationBody,
        payload: 'client_cancelled_session',
      );
    } catch (e) {
      print('Error sending client session cancellation notification: $e');
    }
  }
  
  // Helper method to format session time for display
  String _formatSessionTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final date = '${time.month}/${time.day}/${time.year}';
    return '$date at $hour:$minute $period';
  }
  
  // Send notification for account approval
  Future<void> sendAccountApprovalNotification(String clientId) async {
    // Skip for web platform
    if (kIsWeb) return;
    
    try {
      // Get client's FCM token(s)
      final clientDoc = await _firestore.collection('users').doc(clientId).get();
      final clientData = clientDoc.data();
      if (clientData == null || !clientData.containsKey('fcmTokens')) {
        print('No FCM tokens found for client: $clientId');
        return;
      }
      
      final List<dynamic> fcmTokens = clientData['fcmTokens'] ?? [];
      if (fcmTokens.isEmpty) {
        print('Empty FCM tokens list for client: $clientId');
        return;
      }
      
      // Get client name for personalized notification
      final String clientName = clientData['displayName'] ?? 'there';
      
      // Show a local notification
      await _showLocalNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Account Approved! 🎉',
        body: 'Welcome to Merge Fitness, $clientName! Your account has been approved and you can now access all features.',
        payload: 'account_approved',
      );
      
      print('Account approval notification sent to client: $clientId');
    } catch (e) {
      print('Error sending account approval notification: $e');
    }
  }
  
  // Send notification for account rejection
  Future<void> sendAccountRejectionNotification(String clientId) async {
    // Skip for web platform
    if (kIsWeb) return;
    
    try {
      // Get client's FCM token(s)
      final clientDoc = await _firestore.collection('users').doc(clientId).get();
      final clientData = clientDoc.data();
      if (clientData == null || !clientData.containsKey('fcmTokens')) {
        print('No FCM tokens found for client: $clientId');
        return;
      }
      
      final List<dynamic> fcmTokens = clientData['fcmTokens'] ?? [];
      if (fcmTokens.isEmpty) {
        print('Empty FCM tokens list for client: $clientId');
        return;
      }
      
      // Show a local notification
      await _showLocalNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Account Update',
        body: 'Your account application was not approved. Please contact support at bj@mergeintohealth.com if you believe this was a mistake.',
        payload: 'account_rejected',
      );
      
      print('Account rejection notification sent to client: $clientId');
    } catch (e) {
      print('Error sending account rejection notification: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This is called when the app is in the background and a notification is received
  print("Handling a background message: ${message.messageId}");
  
  // You cannot use any UI related methods here
  // This is only for data-only messages handling
} 