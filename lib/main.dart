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
import 'package:flutter_stripe/flutter_stripe.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/notification_handler.dart';
import 'services/auth_service.dart';
import 'theme/app_styles.dart';
import 'config/env_config.dart';

// Import screens
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/client/client_profile_screen.dart';
import 'screens/client/client_payment_screen.dart';
import 'screens/trainer/trainer_profile_screen.dart';
import 'screens/onboarding_quiz_screen.dart';
import 'screens/client/client_email_verification_screen.dart';
import 'screens/trainer/email_verification_screen.dart';
import 'screens/trainer/trainer_onboarding_screen.dart';

// Global instance of NotificationService for easy access
final NotificationService notificationService = NotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize environment variables
  await EnvConfig.initialize();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Stripe with environment variable
  Stripe.publishableKey = EnvConfig.stripePublishableKey;
  await Stripe.instance.applySettings();
  
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

  // Initialize notification service with delay for auth
  try {
    // Only initialize notifications on mobile platforms
    if (!kIsWeb) {
      // Add a small delay to allow auth to initialize
      await Future.delayed(const Duration(seconds: 1));
      await notificationService.init();
      await notificationService.setupDailyWorkoutReminderCheck();
      
      // Initialize notification handler
      NotificationHandler().initialize();
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
            // Need to check Firestore for actual role instead of displayName
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                String role = 'client'; // default
                if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
                  final userData = roleSnapshot.data!.data() as Map<String, dynamic>?;
                  role = userData?['role'] ?? 'client';
                }
                
            if (role == 'trainer') {
              print("Trainer needs to verify email");
              return TrainerEmailVerificationScreen(user: user);
            } else {
              print("Client needs to verify email");
              return ClientEmailVerificationScreen(user: user);
            }
              },
            );
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
              
              // Handle errors or missing data
              if (userSnapshot.hasError) {
                print("Error loading user data: ${userSnapshot.error}");
                // Show error screen or retry
                return const Scaffold(
                  body: Center(
                    child: Text('Error loading user data. Please try again.'),
                  ),
                );
              }
              
              // Check if user document exists
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                
                // Get role - but don't default to client if missing
                String? role = userData?['role'];
                
                // Log for debugging
                print("User document exists. Role: $role, DisplayName: ${userData?['displayName']}");
                
                // If role is missing or null, this is a data integrity issue
                if (role == null || role.isEmpty) {
                  print("WARNING: User has no role field! User ID: ${snapshot.data!.uid}");
                  print("User data: $userData");
                  
                  // Show error instead of defaulting to client
                  return const Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 48, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            'Account setup incomplete',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please contact support for assistance.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                // Check if user needs to complete onboarding based on role
                if (role == 'client' && (userData == null || userData['displayName'] == null)) {
                  print("Client needs to complete onboarding, redirecting to quiz");
                  return const OnboardingQuizScreen();
                } else if ((role == 'trainer' || role == 'superTrainer') && (userData == null || userData['displayName'] == null)) {
                  print("Trainer/SuperTrainer needs to complete onboarding, redirecting to trainer setup");
                  return const TrainerOnboardingScreen();
                }
                
                // User has completed onboarding
                print("User has completed onboarding, redirecting to home screen");
                return const HomeScreen();
              } else {
                // User document doesn't exist - this is a new user
                print("No user document found for user: ${snapshot.data!.uid}");
                
                // For new users, we need to create a proper user document
                // This situation should be rare since user documents are created during signup
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning, size: 48, color: Colors.orange),
                        SizedBox(height: 16),
                        Text(
                          'Account setup required',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please contact support to complete your account setup.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
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
      builder: (context, child) {
        // Get the original MediaQuery data
        final originalData = MediaQuery.of(context);
        
        // Create new MediaQuery data with accessibility settings forced to normal
        final normalizedData = MediaQueryData(
          size: originalData.size,
          devicePixelRatio: originalData.devicePixelRatio,
          textScaler: const TextScaler.linear(1.0), // Force normal text size
          platformBrightness: originalData.platformBrightness,
          padding: originalData.padding,
          viewInsets: originalData.viewInsets,
          systemGestureInsets: originalData.systemGestureInsets,
          viewPadding: originalData.viewPadding,
          alwaysUse24HourFormat: originalData.alwaysUse24HourFormat,
          accessibleNavigation: false, // Force off
          invertColors: false, // Force off
          highContrast: false, // Force off
          disableAnimations: false, // Force off
          boldText: false, // Force off - this is key for preventing bold text
          navigationMode: originalData.navigationMode,
          gestureSettings: originalData.gestureSettings,
          displayFeatures: originalData.displayFeatures,
        );
        
        return MediaQuery(
          data: normalizedData,
          child: Theme(
            data: ThemeData(
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
                  fontWeight: FontWeight.normal, // Force normal weight
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
              // Explicitly define ALL text styles with normal font weight to override iOS bold text setting
        textTheme: const TextTheme(
                displayLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 32, letterSpacing: -0.5, color: Color(0xFF414141)),
                displayMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 28, letterSpacing: -0.5, color: Color(0xFF414141)),
                displaySmall: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 24, color: Color(0xFF414141)),
                headlineLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 26, letterSpacing: -0.5, color: Color(0xFF414141)),
                headlineMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 22, color: Color(0xFF414141)),
                headlineSmall: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 20, color: Color(0xFF414141)),
                titleLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 18, letterSpacing: 0.15, color: Color(0xFF414141)),
                titleMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 16, color: Color(0xFF414141)),
                titleSmall: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 14, color: Color(0xFF414141)),
                bodyLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 16, color: Color(0xFF414141)),
                bodyMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 14, color: Color(0xFF414141)),
                bodySmall: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 12, color: Color(0xFF414141)),
                labelLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 14, color: Color(0xFF414141)),
                labelMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 12, color: Color(0xFF414141)),
                labelSmall: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 11, color: Color(0xFF414141)),
              ),
              primaryTextTheme: const TextTheme(
                displayLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 32, letterSpacing: -0.5, color: Color(0xFF414141)),
                displayMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 28, letterSpacing: -0.5, color: Color(0xFF414141)),
                displaySmall: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 24, color: Color(0xFF414141)),
                headlineLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 26, letterSpacing: -0.5, color: Color(0xFF414141)),
                headlineMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 22, color: Color(0xFF414141)),
                headlineSmall: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 20, color: Color(0xFF414141)),
                titleLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 18, letterSpacing: 0.15, color: Color(0xFF414141)),
                titleMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 16, color: Color(0xFF414141)),
                titleSmall: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 14, color: Color(0xFF414141)),
                bodyLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 16, color: Color(0xFF414141)),
                bodyMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 14, color: Color(0xFF414141)),
                bodySmall: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 12, color: Color(0xFF414141)),
                labelLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 14, color: Color(0xFF414141)),
                labelMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 12, color: Color(0xFF414141)),
                labelSmall: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.normal, fontSize: 11, color: Color(0xFF414141)),
        ),
      ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.none,
              ),
              child: child!,
            ),
          ),
        );
      },
      title: 'Merge Fitness',
      navigatorKey: NotificationHandler.navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [observer],

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
        '/payment': (context) => const ClientPaymentScreen(),
        '/trainer/profile': (context) => const TrainerProfileScreen(),
      },
    );
  }
}
