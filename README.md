# Merge Fitness - Comprehensive Fitness Training Platform

A comprehensive mobile application built with Flutter that connects fitness trainers with their clients, providing workout management, nutrition tracking, live video training sessions, payment processing, and real-time progress monitoring.

## 🚀 Features Overview

### 🎯 Core Functionality

#### **Authentication & User Management**
- Email/password authentication with Firebase Auth
- Role-based access control (Trainer/Client/Admin)
- Email verification system
- Comprehensive onboarding flow with health questionnaires
- Profile management with photo uploads

#### **Workout Management System**
- **Workout Templates**: Trainers create reusable workout templates
- **Workout Assignment**: Assign workouts to clients with scheduling
- **Exercise Library**: Video demonstrations and detailed instructions
- **Progress Tracking**: Real-time workout completion monitoring
- **Custom Programs**: Multi-week program creation and management

#### **Live Video Training Sessions**
- **Video Calling**: Agora RTC integration for high-quality video calls
- **Tabata Timer**: Real-time synchronized workout timers
- **Session Controls**: Mute, camera toggle, screen sharing
- **Timer Synchronization**: Trainer-controlled timers sync to all participants
- **Session Recording**: Optional session recording capabilities

#### **Nutrition Management**
- **AI Food Recognition**: Take photos to automatically identify and log meals
- **Meal Planning**: Trainers create custom nutrition plans
- **Smart Food Swaps**: AI-powered healthy food alternatives
- **Nutritional Analysis**: Detailed macro and micronutrient tracking
- **Progress Monitoring**: Visual charts and trend analysis

#### **Body Composition Tracking**
- Weight tracking with trend analysis
- Body fat percentage monitoring
- Lean mass calculations
- Progress photos with comparison tools
- Comprehensive body measurement logging

#### **Scheduling & Session Management**
- **Calendly Integration**: Seamless appointment booking
- **Session Packages**: Purchase and manage training session credits
- **Automated Reminders**: Push notifications for upcoming sessions
- **Session History**: Complete training session records
- **Cancellation Management**: Flexible session rescheduling

#### **Payment Processing**
- **Stripe Integration**: Secure payment processing
- **Session Packages**: Purchase training session bundles
- **Payment History**: Complete transaction records
- **Automated Billing**: Recurring payment options
- **Refund Management**: Trainer-initiated refunds

#### **Real-time Location Sharing**
- **Trainer ETA**: Live location sharing for in-person sessions
- **Google Maps Integration**: Route optimization and navigation
- **Geofencing**: Automatic session check-ins
- **Location History**: Session location tracking

#### **Communication & Notifications**
- **Push Notifications**: Firebase Cloud Messaging integration
- **In-app Messaging**: Direct trainer-client communication
- **Activity Feed**: Real-time updates on client progress
- **Automated Reminders**: Workout and session notifications

## 🛠 Tech Stack

### **Frontend**
- **Framework**: Flutter 3.7.2+ (Dart)
- **State Management**: Provider pattern
- **UI Components**: Material Design with custom theming
- **Charts**: FL Chart for data visualization
- **Video Player**: Chewie for exercise demonstrations
- **Image Processing**: Image picker with caching

### **Backend & Cloud Services**
- **Database**: Firebase Firestore (NoSQL)
- **Authentication**: Firebase Auth
- **Storage**: Firebase Storage for media files
- **Functions**: Firebase Cloud Functions (Node.js)
- **Analytics**: Firebase Analytics & Crashlytics
- **Notifications**: Firebase Cloud Messaging

### **Third-party Integrations**
- **Video Calling**: Agora RTC Engine
- **Payments**: Stripe API
- **Scheduling**: Calendly API
- **Maps**: Google Maps Flutter
- **AI**: Google Generative AI (Gemini)
- **Location**: Geolocator & Location services

### **Development Tools**
- **Version Control**: Git
- **CI/CD**: Firebase App Distribution
- **Testing**: Flutter Test Framework
- **Linting**: Flutter Lints
- **Icons**: Flutter Launcher Icons

## 📱 App Architecture

### **Directory Structure**
```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase configuration
├── config/                           # Configuration files
│   ├── agora_config.dart             # Video calling settings
│   ├── api_keys.dart                 # API key management
│   └── env_config.dart               # Environment variables
├── models/                           # Data models
│   ├── user_model.dart               # User data structure
│   ├── workout_model.dart            # Workout data
│   ├── workout_template_model.dart   # Workout templates
│   ├── assigned_workout_model.dart   # Assigned workouts
│   ├── nutrition_plan_model.dart     # Nutrition plans
│   ├── meal_entry_model.dart         # Meal logging
│   ├── food_log_model.dart           # Food recognition
│   ├── body_comp_model.dart          # Body composition
│   ├── weight_entry_model.dart       # Weight tracking
│   ├── session_model.dart            # Training sessions
│   ├── session_package_model.dart    # Session packages
│   ├── payment_history_model.dart    # Payment records
│   ├── video_call_model.dart         # Video call data
│   ├── tabata_timer_model.dart       # Timer functionality
│   ├── onboarding_form_model.dart    # Onboarding data
│   └── goal_model.dart               # User goals
├── services/                         # Business logic
│   ├── auth_service.dart             # Authentication
│   ├── firestore_service.dart        # Database operations
│   ├── workout_service.dart          # Workout management
│   ├── enhanced_workout_service.dart # Advanced workout features
│   ├── workout_template_service.dart # Template management
│   ├── nutrition_service.dart        # Nutrition management
│   ├── meal_service.dart             # Meal logging
│   ├── food_recognition_service.dart # AI food recognition
│   ├── weight_service.dart           # Weight tracking
│   ├── video_service.dart            # Video management
│   ├── video_call_service.dart       # Video calling
│   ├── tabata_service.dart           # Timer functionality
│   ├── payment_service.dart          # Payment processing
│   ├── stripe_backend_service.dart   # Stripe integration
│   ├── calendly_service.dart         # Scheduling
│   ├── notification_service.dart     # Push notifications
│   ├── location_service.dart         # Location services
│   ├── onboarding_service.dart       # Onboarding flow
│   ├── profile_image_service.dart    # Profile management
│   └── session_monitoring_service.dart # Session tracking
├── screens/                          # UI screens
│   ├── login_screen.dart             # Authentication
│   ├── home_screen.dart              # Main navigation
│   ├── onboarding_quiz_screen.dart   # Initial setup
│   ├── shared/                       # Shared screens
│   │   └── video_call_screen.dart    # Video calling interface
│   ├── client/                       # Client-specific screens
│   │   ├── client_dashboard.dart     # Client home
│   │   ├── client_workouts_screen.dart # Workout management
│   │   ├── workout_detail_screen.dart # Workout execution
│   │   ├── client_progress_screen.dart # Progress tracking
│   │   ├── client_nutrition_screen.dart # Nutrition management
│   │   ├── meal_entry_screen.dart    # Meal logging
│   │   ├── client_profile_screen.dart # Profile management
│   │   ├── schedule_session_screen.dart # Session booking
│   │   ├── all_sessions_screen.dart  # Session history
│   │   ├── client_payment_screen.dart # Payment management
│   │   ├── select_trainer_screen.dart # Trainer selection
│   │   ├── trainer_location_screen.dart # Location tracking
│   │   └── client_email_verification_screen.dart
│   └── trainer/                      # Trainer-specific screens
│       ├── trainer_dashboard.dart    # Trainer home
│       ├── clients_screen.dart       # Client management
│       ├── client_details_screen.dart # Client profiles
│       ├── client_progress_screen.dart # Client progress
│       ├── assign_workout_screen.dart # Workout assignment
│       ├── create_template_screen.dart # Template creation
│       ├── templates_screen.dart     # Template management
│       ├── assign_nutrition_plan_screen.dart # Nutrition planning
│       ├── trainer_scheduling_screen.dart # Schedule management
│       ├── trainer_profile_screen.dart # Trainer profile
│       ├── video_gallery_screen.dart # Exercise videos
│       ├── location_sharing_screen.dart # Location sharing
│       ├── client_payment_tab.dart   # Payment tracking
│       ├── client_meal_history_screen.dart # Meal monitoring
│       ├── client_onboarding_details_screen.dart
│       ├── client_agreement_document_screen.dart
│       ├── client_info_screen.dart
│       ├── trainer_onboarding_screen.dart
│       └── email_verification_screen.dart
├── widgets/                          # Reusable components
│   ├── merge_app_bar.dart           # Custom app bar
│   ├── merge_button.dart            # Custom buttons
│   ├── merge_card.dart              # Custom cards
│   ├── profile_avatar.dart          # Profile images
│   ├── session_time_slot.dart       # Time selection
│   ├── tabata_timer_widget.dart     # Timer display
│   ├── tabata_config_dialog.dart    # Timer configuration
│   ├── signature_capture_widget.dart # Digital signatures
│   ├── photo_capture_widget.dart    # Photo capture
│   └── onboarding_form_widgets.dart # Onboarding components
└── theme/                           # App theming
    └── app_theme.dart               # Theme configuration
```

### **Firebase Collections Structure**
```
users/{uid}
  - email, role, height, dob, goals, trainerId, profileImageUrl

workoutTemplates/{templateId}
  - trainerId, title, description, exercises[], difficulty, estimatedDuration

assignedWorkouts/{workoutId}
  - clientId, trainerId, templateId, scheduledDate, status, completedAt

nutritionPlans/{planId}
  - clientId, trainerId, title, meals[], startDate, endDate, goals

meals/{mealId}
  - clientId, date, mealType, foods[], totalCalories, macros

bodyComp/{userId}/entries/{entryId}
  - date, weight, bodyFatPct, leanMassKg, measurements

sessions/{sessionId}
  - clientId, trainerId, startTime, endTime, status, type, notes

sessionPackages/{packageId}
  - clientId, trainerId, sessionsTotal, sessionsRemaining, purchaseDate

paymentHistory/{paymentId}
  - clientId, trainerId, amount, sessionsPurchased, stripePaymentIntentId

video_calls/{callId}
  - sessionId, trainerId, clientId, channelName, status, createdAt

tabata_timers/{timerId}
  - videoCallId, trainerId, clientId, exerciseTime, restTime, rounds

onboardingForms/{formId}
  - clientId, healthData, goals, preferences, completedAt

foodLogs/{logId}
  - userId, timestamp, photoUrl, recognizedFoods[], nutritionData

trainerVideos/{videoId}
  - trainerId, title, description, videoUrl, thumbnailUrl, category

activityFeed/{activityId}
  - trainerId, clientId, type, message, timestamp, data
```

## 🚀 Getting Started

### **Prerequisites**
- Flutter SDK 3.7.2 or later
- Dart SDK 2.15.x or later
- Firebase CLI
- Android Studio / Xcode for mobile development
- Node.js 16+ (for Cloud Functions)
- Git

### **Installation Steps**

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/merge_fitness.git
   cd merge_fitness
   ```

2. **Install Flutter Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   ```bash
   # Install Firebase CLI if not already installed
   npm install -g firebase-tools
   
   # Login to Firebase
   firebase login
   
   # Configure Firebase for Flutter
   flutterfire configure
   ```

4. **Environment Configuration**
   Create a `.env` file in the root directory:
   ```env
   STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_key
   GOOGLE_GENERATIVE_AI_API_KEY=your_gemini_api_key
   AGORA_APP_ID=your_agora_app_id
   ```

5. **Firebase Functions Setup**
   ```bash
   cd functions
   npm install
   
   # Set Stripe configuration
   firebase functions:config:set stripe.secret_key="sk_test_your_stripe_secret"
   firebase functions:config:set stripe.webhook_secret="whsec_your_webhook_secret"
   
   cd ..
   ```

6. **Deploy Firebase Configuration**
   ```bash
   # Deploy Firestore rules and indexes
   firebase deploy --only firestore
   
   # Deploy Cloud Functions
   firebase deploy --only functions
   
   # Deploy Storage rules
   firebase deploy --only storage
   ```

7. **Platform-Specific Setup**

   **Android:**
   - Add `google-services.json` to `android/app/`
   - Update `android/app/src/main/AndroidManifest.xml` with required permissions
   - Add Google Maps API key to `android/app/src/main/AndroidManifest.xml`

   **iOS:**
   - Add `GoogleService-Info.plist` to `ios/Runner/`
   - Update `ios/Runner/Info.plist` with required permissions
   - Add Google Maps API key to `ios/Runner/AppDelegate.swift`

8. **Run the Application**
   ```bash
   # Run on connected device/emulator
   flutter run
   
   # Run in debug mode
   flutter run --debug
   
   # Build for release
   flutter build apk --release  # Android
   flutter build ios --release  # iOS
   ```

### **Third-Party Service Configuration**

#### **Agora Video Calling**
1. Create account at [Agora.io](https://www.agora.io/)
2. Create a new project and get App ID
3. Update `lib/config/agora_config.dart` with your App ID
4. Configure token server for production use

#### **Stripe Payments**
1. Create account at [Stripe](https://stripe.com/)
2. Get publishable and secret keys
3. Configure webhook endpoint for payment confirmations
4. Update Firebase Functions with Stripe configuration

#### **Google AI (Gemini)**
1. Get API key from [Google AI Studio](https://makersuite.google.com/)
2. Add to environment configuration
3. Configure usage limits and safety settings

#### **Calendly Integration**
1. Create Calendly developer account
2. Set up OAuth application
3. Configure redirect URLs for mobile app
4. Update service configuration

## 🔧 Configuration

### **Firebase Security Rules**
The app uses comprehensive Firestore security rules that enforce:
- Role-based access control
- Data ownership validation
- Trainer-client relationship verification
- Admin privilege management

### **Firestore Indexes**
Optimized indexes are configured for:
- User queries by role and trainer relationships
- Workout and nutrition plan filtering
- Session scheduling and history
- Payment and activity tracking
- Video call and timer synchronization

### **Push Notifications**
Configured for:
- Workout reminders
- Session notifications
- Payment confirmations
- Progress updates
- Emergency alerts

## 📊 Key Features Deep Dive

### **Live Video Training**
- **Real-time Communication**: Agora RTC engine provides low-latency video/audio
- **Synchronized Timers**: Tabata timers sync across all participants
- **Session Recording**: Optional recording for review and progress tracking
- **Screen Sharing**: Trainers can share workout plans and demonstrations
- **Multi-participant Support**: Group training session capabilities

### **AI-Powered Nutrition**
- **Food Recognition**: Camera-based meal identification using Google AI
- **Nutritional Analysis**: Automatic macro and micronutrient calculation
- **Smart Recommendations**: Personalized food swap suggestions
- **Progress Tracking**: Visual charts showing nutritional trends
- **Meal Planning**: Trainer-created custom meal plans

### **Advanced Workout Management**
- **Template System**: Reusable workout templates with exercise libraries
- **Progress Tracking**: Real-time completion monitoring
- **Video Demonstrations**: Integrated exercise instruction videos
- **Custom Programs**: Multi-week progressive training programs
- **Performance Analytics**: Detailed workout statistics and trends

### **Payment & Billing**
- **Secure Processing**: PCI-compliant Stripe integration
- **Session Packages**: Flexible credit-based system
- **Automated Billing**: Recurring payment options
- **Payment History**: Complete transaction records
- **Refund Management**: Trainer-initiated refunds

## 🧪 Testing

### **Running Tests**
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run integration tests
flutter drive --target=test_driver/app.dart
```

### **Test Structure**
- Unit tests for services and models
- Widget tests for UI components
- Integration tests for user flows
- Firebase emulator tests for backend logic

## 🚀 Deployment

### **Development Deployment**
```bash
# Deploy to Firebase App Distribution
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app 1:394880012668:android:65a7bccd22e7c48fcb54f9 \
  --groups "testers"
```

### **Production Deployment**
```bash
# Build release versions
flutter build apk --release --split-per-abi
flutter build ios --release

# Deploy to app stores using fastlane or manual upload
```

### **Backend Deployment**
```bash
# Deploy all Firebase services
firebase deploy

# Deploy specific services
firebase deploy --only firestore
firebase deploy --only functions
firebase deploy --only storage
```

## 🔒 Security & Privacy

### **Data Protection**
- End-to-end encryption for sensitive data
- HIPAA-compliant health data handling
- Secure file storage with access controls
- Regular security audits and updates

### **Authentication Security**
- Multi-factor authentication support
- Session management and timeout
- Role-based access control
- Secure password requirements

### **Payment Security**
- PCI DSS compliant payment processing
- Tokenized payment methods
- Secure webhook validation
- Fraud detection and prevention

## 📈 Analytics & Monitoring

### **Firebase Analytics**
- User engagement tracking
- Feature usage analytics
- Performance monitoring
- Crash reporting and analysis

### **Custom Metrics**
- Workout completion rates
- Session attendance tracking
- Payment success rates
- User retention analysis

## 🤝 Contributing

### **Development Workflow**
1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Follow coding standards and add tests
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open Pull Request

### **Code Standards**
- Follow Dart/Flutter style guide
- Add comprehensive documentation
- Include unit tests for new features
- Use meaningful commit messages
- Update README for new features

## 📞 Support & Documentation

### **Getting Help**
- Check existing issues on GitHub
- Review documentation and code comments
- Contact development team for technical support
- Join community discussions

### **Additional Resources**
- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Agora Documentation](https://docs.agora.io/)
- [Stripe Documentation](https://stripe.com/docs)

## 📄 License

This project is proprietary and confidential. All rights reserved.

---

**Merge Fitness** - Transforming personal training through technology 💪📱
