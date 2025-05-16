import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'theme/app_styles.dart';

// Import screens
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/client/client_profile_screen.dart';
import 'screens/trainer/trainer_profile_screen.dart';
import 'screens/onboarding_quiz_screen.dart';
import 'screens/client/client_email_verification_screen.dart';
import 'screens/trainer/email_verification_screen.dart';
import 'screens/trainer/trainer_onboarding_screen.dart';

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

/// Auth wrapper widget that handles authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();
    
    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // If the snapshot has user data, then user is logged in
        if (snapshot.hasData) {
          // Check if user is email verified
          User user = snapshot.data as User;
          if (!user.emailVerified) {
            // If not verified, redirect to appropriate verification screen
            final String role = user.displayName?.startsWith('trainer_') == true ? 'trainer' : 'client';
            if (role == 'trainer') {
              print("Trainer needs to verify email");
              return TrainerEmailVerificationScreen(user: user);
            } else {
              print("Client needs to verify email");
              return ClientEmailVerificationScreen(user: user);
            }
          }
          
          // Check if user has completed onboarding by checking their profile data
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              // Check if user document exists and has display name (indicating completed onboarding)
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                final String role = userData?['role'] ?? 'client';
                
                // Check if user needs to complete onboarding based on role
                if (role == 'client' && (userData == null || userData['displayName'] == null)) {
                  print("Client needs to complete onboarding, redirecting to quiz");
                  return const OnboardingQuizScreen();
                } else if (role == 'trainer' && (userData == null || userData['displayName'] == null)) {
                  print("Trainer needs to complete onboarding, redirecting to trainer setup");
                  return const TrainerOnboardingScreen();
                }
                
                // User has completed onboarding
                return const HomeScreen();
              } else {
                // New user without profile data needs onboarding
                print("New user detected, checking role for proper onboarding");
                
                // Check Firestore for role information to direct to correct onboarding
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
                  builder: (context, roleSnapshot) {
                    if (roleSnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    
                    // Check if the user document exists and determine role
                    if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
                      final userData = roleSnapshot.data!.data() as Map<String, dynamic>?;
                      final String role = userData?['role'] ?? 'client';
                      
                      if (role == 'trainer') {
                        print("New trainer detected, redirecting to trainer setup");
                        return const TrainerOnboardingScreen();
                      } else {
                        print("New client detected, redirecting to onboarding quiz");
                        return const OnboardingQuizScreen();
                      }
                    }
                    
                    // Default to client onboarding if we can't determine role
                    return const OnboardingQuizScreen();
                  },
                );
              }
            },
          );
        }
        
        // Otherwise, user is not logged in
        return const LoginScreen();
      },
    );
  }
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
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: AppStyles.primarySage,
        colorScheme: ColorScheme.light(
          primary: AppStyles.primarySage, // Soft sage green
          secondary: AppStyles.taupeBrown, // Taupe brown
          tertiary: AppStyles.mutedBlue, // Muted blue
          background: AppStyles.offWhite, // Off-white/soft beige 
          surface: Colors.white,
          onBackground: AppStyles.textDark, 
          onSurface: AppStyles.textDark,
          primaryContainer: AppStyles.subtleAccent, 
          secondaryContainer: AppStyles.taupeBrown.withOpacity(0.2),
          error: AppStyles.errorRed,
        ),
        scaffoldBackgroundColor: AppStyles.offWhite,
        cardColor: Colors.white,
        fontFamily: 'Montserrat',
        appBarTheme: AppBarTheme(
          backgroundColor: AppStyles.offWhite,
          foregroundColor: AppStyles.slateGray,
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 56, // Standard height
          iconTheme: IconThemeData(color: AppStyles.slateGray),
          titleTextStyle: TextStyle(
            color: AppStyles.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Montserrat',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppStyles.primaryButtonStyle,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: AppStyles.secondaryButtonStyle,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppStyles.primarySage, width: 1.5),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w500, letterSpacing: -0.5, color: Color(0xFF414141)),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, letterSpacing: -0.5, color: Color(0xFF414141)),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Color(0xFF414141)),
          headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, letterSpacing: -0.5, color: Color(0xFF414141)),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF414141)),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xFF414141)),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 0.15, color: Color(0xFF414141)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: AppStyles.primarySage,
        colorScheme: ColorScheme.light(
          primary: AppStyles.primarySage,
          secondary: AppStyles.taupeBrown,
          tertiary: AppStyles.mutedBlue,
          background: AppStyles.offWhite,
          surface: Colors.white,
          onBackground: AppStyles.textDark,
          onSurface: AppStyles.textDark,
          primaryContainer: AppStyles.subtleAccent,
          secondaryContainer: AppStyles.taupeBrown.withOpacity(0.2),
          error: AppStyles.errorRed,
        ),
        scaffoldBackgroundColor: AppStyles.offWhite,
        cardColor: Colors.white,
        fontFamily: 'Montserrat',
        appBarTheme: AppBarTheme(
          backgroundColor: AppStyles.offWhite,
          foregroundColor: AppStyles.slateGray,
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 56,
          iconTheme: IconThemeData(color: AppStyles.slateGray),
          titleTextStyle: TextStyle(
            color: AppStyles.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Montserrat',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppStyles.primaryButtonStyle,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: AppStyles.secondaryButtonStyle,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppStyles.primarySage, width: 1.5),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w500, letterSpacing: -0.5, color: Color(0xFF414141)),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, letterSpacing: -0.5, color: Color(0xFF414141)),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Color(0xFF414141)),
          headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, letterSpacing: -0.5, color: Color(0xFF414141)),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF414141)),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xFF414141)),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 0.15, color: Color(0xFF414141)),
        ),
      ),
      themeMode: ThemeMode.light,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/client/profile': (context) => const ClientProfileScreen(),
        '/trainer/profile': (context) => const TrainerProfileScreen(),
      },
    );
  }
}
