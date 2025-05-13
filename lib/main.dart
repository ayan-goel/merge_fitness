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
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1A73E8),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1A73E8), // Electric blue
          secondary: Color(0xFFE6C170), // Soft gold
          tertiary: Color(0xFF9C27B0), // Deep plum
          background: Color(0xFF121212), // Deep charcoal
          surface: Color(0xFF1E1E1E), // Slightly lighter charcoal
          onBackground: Color(0xFFF5F5F5), // Off-white for text on background
          onSurface: Color(0xFFF5F5F5), // Off-white for text on surface
          primaryContainer: Color(0xFF1A367E), // Darker blue
          secondaryContainer: Color(0xFF635839), // Darker gold
          error: Color(0xFFCF6679), // Soft red for errors
        ),
        fontFamily: 'Montserrat',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.15),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: 0.5),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: 0.25),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, letterSpacing: 0.4),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, letterSpacing: 1.5),
          labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.normal, letterSpacing: 1.5),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A73E8),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1A73E8),
            side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1A73E8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Color(0xFFF5F5F5),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          hintStyle: const TextStyle(color: Color(0xFF8E8E8E)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF2C2C2C),
          disabledColor: const Color(0xFF3D3D3D),
          selectedColor: const Color(0xFF1A73E8),
          secondarySelectedColor: const Color(0xFF1A73E8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          labelStyle: const TextStyle(
            color: Color(0xFFF5F5F5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF3D3D3D),
          thickness: 1,
          space: 32,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF121212),
          selectedItemColor: Color(0xFF1A73E8),
          unselectedItemColor: Color(0xFF8E8E8E),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFF5F5F5),
          size: 24,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1A73E8),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1A73E8), // Electric blue
          secondary: Color(0xFFE6C170), // Soft gold
          tertiary: Color(0xFF9C27B0), // Deep plum
          background: Color(0xFF121212), // Deep charcoal
          surface: Color(0xFF1E1E1E), // Slightly lighter charcoal
          onBackground: Color(0xFFF5F5F5), // Off-white for text on background
          onSurface: Color(0xFFF5F5F5), // Off-white for text on surface
          primaryContainer: Color(0xFF1A367E), // Darker blue
          secondaryContainer: Color(0xFF635839), // Darker gold
          error: Color(0xFFCF6679), // Soft red for errors
        ),
        fontFamily: 'Montserrat',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.15),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: 0.5),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: 0.25),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, letterSpacing: 0.4),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, letterSpacing: 1.5),
          labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.normal, letterSpacing: 1.5),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A73E8),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1A73E8),
            side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1A73E8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Color(0xFFF5F5F5),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          hintStyle: const TextStyle(color: Color(0xFF8E8E8E)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF2C2C2C),
          disabledColor: const Color(0xFF3D3D3D),
          selectedColor: const Color(0xFF1A73E8),
          secondarySelectedColor: const Color(0xFF1A73E8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          labelStyle: const TextStyle(
            color: Color(0xFFF5F5F5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF3D3D3D),
          thickness: 1,
          space: 32,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF121212),
          selectedItemColor: Color(0xFF1A73E8),
          unselectedItemColor: Color(0xFF8E8E8E),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFF5F5F5),
          size: 24,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: ThemeMode.dark, // Force dark theme
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
