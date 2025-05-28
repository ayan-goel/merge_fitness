import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get stripePublishableKey => dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  static String get stripeSecretKey => dotenv.env['STRIPE_SECRET_KEY'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  
  static bool get isDevelopment => appEnv == 'development';
  static bool get isProduction => appEnv == 'production';
  
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
  }
} 