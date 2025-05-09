import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

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
    }
    
    // Set up foreground notification handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Set up background message handler for mobile platforms
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
    
    // Handle notification when app is opened from terminated state
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
    
    // Handle when app is opened from background state
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Get and store FCM token
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveFcmToken(token);
    }
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveFcmToken);
  }
  
  // Save FCM token to Firestore for the current user
  Future<void> _saveFcmToken(String token) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastActive': FieldValue.serverTimestamp(),
      });
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
    // Handle notification tap
    // You can navigate to specific screens based on payload
    print('Notification tapped with payload: ${response.payload}');
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
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This is called when the app is in the background and a notification is received
  print("Handling a background message: ${message.messageId}");
  
  // You cannot use any UI related methods here
  // This is only for data-only messages handling
} 