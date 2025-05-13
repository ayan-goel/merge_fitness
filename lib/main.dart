import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'firebase_options.dart';
import 'services/notification_service.dart';

// Import screens
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/client/client_profile_screen.dart';
import 'screens/trainer/trainer_profile_screen.dart';

// Global instance of NotificationService for easy access
final NotificationService notificationService = NotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize timezone data
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/New_York')); // Set EST as the default
  
  // Initialize Crashlytics only for mobile platforms
  if (!kIsWeb) {
    // Initialize Crashlytics
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    
    // Pass all uncaught errors to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  }

  // Initialize notification service
  try {
    // Only initialize notifications on mobile platforms
    if (!kIsWeb) {
      await notificationService.init();
      await notificationService.setupDailyWorkoutReminderCheck();
    } else {
      // For web, use a simpler initialization that doesn't require service workers
      await notificationService.initWebWithoutPush();
    }
  } catch (e) {
    print('Error initializing notifications: $e');
    // Continue with app startup even if notifications fail
  }

  runApp(const MergeFitnessApp());
}

class MergeFitnessApp extends StatelessWidget {
  const MergeFitnessApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merge Fitness',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [observer],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5D2FDA), // Purple primary color
          primary: const Color(0xFF5D2FDA),
          secondary: const Color(0xFF00E1D5), // Teal secondary color
          background: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF5D2FDA)),
          titleTextStyle: TextStyle(
            color: Color(0xFF5D2FDA),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222222),
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222222),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5D2FDA),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      // For now we'll start with the login screen.
      // Later we'll add authentication state checking to determine the starting screen.
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/client/profile': (context) => const ClientProfileScreen(),
        '/trainer/profile': (context) => const TrainerProfileScreen(),
      },
    );
  }
}
