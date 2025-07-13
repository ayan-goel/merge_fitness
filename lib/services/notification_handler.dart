import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../screens/client/client_workouts_screen.dart';
import '../screens/client/workout_detail_screen.dart';
import '../screens/trainer/client_details_screen.dart';
import '../screens/trainer/trainer_dashboard.dart';
import '../screens/client/client_dashboard.dart';
import '../screens/shared/video_call_screen.dart';
import '../screens/client/client_nutrition_screen.dart';
import '../screens/client/meal_entry_screen.dart';
import '../screens/trainer/clients_screen.dart';
import '../screens/trainer/trainer_schedule_view_screen.dart';
import '../models/assigned_workout_model.dart';
import '../services/auth_service.dart';

class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Initialize notification handling
  void initialize() {
    // Handle notification when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from terminated state via notification: ${message.data}');
        _handleNotificationData(message.data);
      }
    });

    // Handle notification when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background via notification: ${message.data}');
      _handleNotificationData(message.data);
    });

    // Handle notification when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notification received in foreground: ${message.data}');
      // In foreground, just log the notification - local notification will be shown
    });
  }

  /// Handle notification data and navigate accordingly
  void _handleNotificationData(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final String? type = data['type'];
    print('Handling notification type: $type');

    switch (type) {
      case 'workout_assigned':
        _handleWorkoutAssigned(data);
        break;
      case 'workout_completed':
        _handleWorkoutCompleted(data);
        break;
      case 'session_booked':
        _handleSessionBooked(data);
        break;
      case 'session_cancelled':
        _handleSessionCancelled(data);
        break;
      case 'session_reminder':
        _handleSessionReminder(data);
        break;
      case 'nutrition_plan_assigned':
        _handleNutritionPlanAssigned(data);
        break;
      case 'meal_logged':
        _handleMealLogged(data);
        break;
      case 'message_received':
        _handleMessageReceived(data);
        break;
      case 'payment_success':
        _handlePaymentSuccess(data);
        break;
      case 'account_approved':
        _handleAccountApproved(data);
        break;
      case 'account_rejected':
        _handleAccountRejected(data);
        break;
      case 'workout_reminder':
        _handleWorkoutReminder(data);
        break;
      default:
        print('Unknown notification type: $type');
    }
  }

  /// Handle workout assigned notification
  void _handleWorkoutAssigned(Map<String, dynamic> data) {
    final String? workoutId = data['workoutId'];
    final String? trainerId = data['trainerId'];
    
    if (workoutId != null) {
      // Navigate to workouts screen for client
      _navigateToRoute('/client/workouts', arguments: {
        'highlightWorkout': workoutId,
        'trainerId': trainerId,
      });
    }
  }

  /// Handle workout completed notification
  void _handleWorkoutCompleted(Map<String, dynamic> data) {
    final String? workoutId = data['workoutId'];
    final String? clientId = data['clientId'];
    
    if (clientId != null) {
      // Navigate to client details screen for trainer
      _navigateToClientDetails(clientId);
    }
  }

  /// Handle session booked notification
  void _handleSessionBooked(Map<String, dynamic> data) {
    final String? sessionId = data['sessionId'];
    final String? clientId = data['clientId'];
    
    // Navigate to trainer schedule view
    _navigateToRoute('/trainer/schedule', arguments: {
      'highlightSession': sessionId,
      'clientId': clientId,
    });
  }

  /// Handle session cancelled notification
  void _handleSessionCancelled(Map<String, dynamic> data) {
    final String? sessionId = data['sessionId'];
    final String? clientId = data['clientId'];
    final String? trainerId = data['trainerId'];
    
    // Check user role and navigate accordingly
    final authService = AuthService();
    final user = authService.currentUser;
    
    if (user != null) {
      // Navigate to appropriate schedule view
      if (trainerId != null) {
        _navigateToRoute('/trainer/schedule', arguments: {
          'highlightSession': sessionId,
          'clientId': clientId,
        });
      } else if (clientId != null) {
        _navigateToRoute('/client/sessions', arguments: {
          'highlightSession': sessionId,
          'trainerId': trainerId,
        });
      }
    }
  }

  /// Handle session reminder notification
  void _handleSessionReminder(Map<String, dynamic> data) {
    final String? sessionId = data['sessionId'];
    final String? clientId = data['clientId'];
    final String? trainerId = data['trainerId'];
    
    // Navigate to session details or schedule
    if (sessionId != null) {
      _navigateToRoute('/session/details', arguments: {
        'sessionId': sessionId,
        'clientId': clientId,
        'trainerId': trainerId,
      });
    }
  }

  /// Handle nutrition plan assigned notification
  void _handleNutritionPlanAssigned(Map<String, dynamic> data) {
    final String? planId = data['planId'];
    final String? trainerId = data['trainerId'];
    
    // Navigate to nutrition screen for client
    _navigateToRoute('/client/nutrition', arguments: {
      'highlightPlan': planId,
      'trainerId': trainerId,
    });
  }

  /// Handle meal logged notification
  void _handleMealLogged(Map<String, dynamic> data) {
    final String? entryId = data['entryId'];
    final String? clientId = data['clientId'];
    
    if (clientId != null) {
      // Navigate to client meal history for trainer
      _navigateToClientMealHistory(clientId);
    }
  }

  /// Handle message received notification
  void _handleMessageReceived(Map<String, dynamic> data) {
    final String? conversationId = data['conversationId'];
    final String? senderId = data['senderId'];
    
    // Navigate to chat/messaging screen
    _navigateToRoute('/chat', arguments: {
      'conversationId': conversationId,
      'senderId': senderId,
    });
  }

  /// Handle payment success notification
  void _handlePaymentSuccess(Map<String, dynamic> data) {
    final int? amount = data['amount'];
    final int? sessions = data['sessions'];
    
    // Navigate to payment history or dashboard
    _navigateToRoute('/client/payment', arguments: {
      'showSuccess': true,
      'amount': amount,
      'sessions': sessions,
    });
  }

  /// Handle account approved notification
  void _handleAccountApproved(Map<String, dynamic> data) {
    // Navigate to main dashboard
    _navigateToRoute('/dashboard');
  }

  /// Handle account rejected notification
  void _handleAccountRejected(Map<String, dynamic> data) {
    // Navigate to rejection screen or contact support
    _navigateToRoute('/support');
  }

  /// Handle workout reminder notification
  void _handleWorkoutReminder(Map<String, dynamic> data) {
    final String? workoutId = data['workoutId'];
    
    if (workoutId != null) {
      // Navigate to workout details
      _navigateToRoute('/workout/details', arguments: {
        'workoutId': workoutId,
      });
    }
  }

  /// Helper method to navigate to a route
  void _navigateToRoute(String route, {Map<String, dynamic>? arguments}) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Add delay to ensure app is fully loaded
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.of(context).pushNamed(route, arguments: arguments);
      });
    }
  }

  /// Helper method to navigate to client details
  void _navigateToClientDetails(String clientId) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ClientDetailsScreen(
              clientId: clientId,
              clientName: 'Client', // Will be loaded from Firestore
            ),
          ),
        );
      });
    }
  }

  /// Helper method to navigate to client meal history
  void _navigateToClientMealHistory(String clientId) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        // Navigate to client meal history screen
        Navigator.of(context).pushNamed('/trainer/client/meals', arguments: {
          'clientId': clientId,
        });
      });
    }
  }

  /// Handle notification payload (for local notifications)
  void handleNotificationPayload(String? payload) {
    if (payload == null) return;
    
    print('Handling notification payload: $payload');
    
    // Parse payload and handle accordingly
    if (payload.startsWith('workout_reminder:')) {
      final workoutId = payload.split(':')[1];
      _handleWorkoutReminder({'workoutId': workoutId});
    } else if (payload.startsWith('workout_checkin:')) {
      final workoutId = payload.split(':')[1];
      _handleWorkoutReminder({'workoutId': workoutId});
    } else if (payload == 'account_approved') {
      _handleAccountApproved({});
    } else if (payload == 'account_rejected') {
      _handleAccountRejected({});
    }
  }
} 