# Merge Fitness

A comprehensive mobile fitness platform built with Flutter that connects trainers with clients for workout management, nutrition tracking, live video sessions, and progress monitoring.

## Features

### For Trainers
- **Client Management**: Manage multiple clients with detailed profiles and progress tracking
- **Workout Templates**: Create reusable workout templates with exercise videos and instructions
- **Nutrition Templates**: Build meal plan templates with macros, micros, and sample meals
- **Live Video Sessions**: Conduct real-time training sessions with synchronized Tabata timers
- **Session Scheduling**: Calendly integration for seamless appointment booking
- **Progress Monitoring**: Track client workouts, nutrition, body composition, and weight
- **Messaging**: Real-time chat with assigned clients
- **Payment Tracking**: Monitor session packages and payment history
- **Location Sharing**: Share live location and ETA for in-person sessions
- **Video Gallery**: Shared library of exercise demonstration videos

### For Clients
- **Workout Access**: View assigned workouts with video demonstrations and instructions
- **Nutrition Tracking**: AI-powered food recognition and meal logging
- **Body Composition**: Track weight, body fat, measurements, and progress photos
- **Session Booking**: Schedule training sessions via Calendly integration
- **Session Packages**: Purchase training session credits via Stripe
- **Live Training**: Join video sessions with trainers
- **Messaging**: Chat with assigned trainers and super trainer
- **Progress Dashboard**: Visual charts and analytics for all metrics
- **Onboarding**: Comprehensive health questionnaire and goal setting

### Shared Features
- **Video Calling**: Agora RTC integration for high-quality live sessions
- **Real-time Sync**: Firestore-powered live updates across all features
- **Push Notifications**: Automated reminders for workouts and sessions
- **Timezone Support**: Automatic timezone conversion for global users
- **Search**: Fast template search by name across workouts and meal plans

## Tech Stack

**Frontend**: Flutter 3.7.2+ (Dart)  
**Backend**: Firebase (Firestore, Auth, Storage, Functions, FCM)  
**Video**: Agora RTC Engine  
**Payments**: Stripe API  
**Scheduling**: Calendly API  
**AI**: Google Generative AI (Gemini)  
**Maps**: Google Maps Flutter  

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase configuration
├── config/
│   ├── agora_config.dart             # Video calling settings
│   ├── api_keys.dart                 # API key management
│   └── env_config.dart               # Environment variables
├── models/
│   ├── user_model.dart
│   ├── workout_model.dart
│   ├── workout_template_model.dart
│   ├── assigned_workout_model.dart
│   ├── nutrition_plan_model.dart
│   ├── nutrition_plan_template_model.dart
│   ├── meal_entry_model.dart
│   ├── food_log_model.dart
│   ├── body_comp_model.dart
│   ├── weight_entry_model.dart
│   ├── session_model.dart
│   ├── session_package_model.dart
│   ├── payment_history_model.dart
│   ├── video_call_model.dart
│   ├── tabata_timer_model.dart
│   ├── message_model.dart
│   ├── onboarding_form_model.dart
│   ├── family_model.dart
│   └── goal_model.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── workout_service.dart
│   ├── enhanced_workout_service.dart
│   ├── workout_template_service.dart
│   ├── nutrition_service.dart
│   ├── food_recognition_service.dart
│   ├── weight_service.dart
│   ├── video_service.dart
│   ├── video_call_service.dart
│   ├── tabata_service.dart
│   ├── payment_service.dart
│   ├── stripe_backend_service.dart
│   ├── calendly_service.dart
│   ├── notification_service.dart
│   ├── location_service.dart
│   ├── messaging_service.dart
│   ├── onboarding_service.dart
│   ├── family_service.dart
│   └── session_monitoring_service.dart
├── screens/
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── onboarding_quiz_screen.dart
│   ├── shared/
│   │   ├── video_call_screen.dart
│   │   ├── conversations_screen.dart
│   │   └── chat_screen.dart
│   ├── client/
│   │   ├── client_dashboard.dart
│   │   ├── client_workouts_screen.dart
│   │   ├── workout_detail_screen.dart
│   │   ├── client_progress_screen.dart
│   │   ├── client_nutrition_screen.dart
│   │   ├── meal_entry_screen.dart
│   │   ├── client_profile_screen.dart
│   │   ├── client_editable_onboarding_screen.dart
│   │   ├── schedule_session_screen.dart
│   │   ├── all_sessions_screen.dart
│   │   ├── client_payment_screen.dart
│   │   ├── select_trainer_screen.dart
│   │   └── trainer_location_screen.dart
│   └── trainer/
│       ├── trainer_dashboard.dart
│       ├── clients_screen.dart
│       ├── client_details_screen.dart
│       ├── client_progress_screen.dart
│       ├── assign_workout_screen.dart
│       ├── create_template_screen.dart
│       ├── templates_screen.dart
│       ├── create_nutrition_template_screen.dart
│       ├── assign_nutrition_plan_screen.dart
│       ├── trainer_scheduling_screen.dart
│       ├── trainer_schedule_view_screen.dart
│       ├── trainer_profile_screen.dart
│       ├── video_gallery_screen.dart
│       ├── location_sharing_screen.dart
│       ├── client_meal_history_screen.dart
│       ├── client_onboarding_details_screen.dart
│       ├── super_trainer_admin_screen.dart
│       └── financial_analytics_screen.dart
├── widgets/
│   ├── merge_app_bar.dart
│   ├── merge_button.dart
│   ├── merge_card.dart
│   ├── session_time_slot.dart
│   ├── tabata_timer_widget.dart
│   ├── tabata_config_dialog.dart
│   ├── signature_capture_widget.dart
│   ├── photo_capture_widget.dart
│   └── onboarding_form_widgets.dart
└── theme/
    ├── app_styles.dart
    ├── app_theme.dart
    ├── app_animations.dart
    ├── app_widgets.dart
    └── ui_helpers.dart
```

## Key Features Deep Dive

### Live Video Training
Real-time video sessions powered by Agora RTC with synchronized Tabata timers. Trainers control workout intervals that sync across all participants, enabling group training sessions with precise timing. Sessions support mute, camera toggle, and screen sharing for demonstrations.

### AI-Powered Nutrition
Google Gemini API analyzes meal photos to automatically identify foods and calculate nutritional information. The system provides macro/micro breakdowns, suggests healthy food swaps, and tracks daily nutrition goals with visual progress charts.

### Template System
Trainers create reusable workout and nutrition templates that are shared across all trainers. Templates include exercise videos, detailed instructions, macro/micro targets, and sample meals. The search feature allows quick filtering by name with real-time results.

### Messaging System
Firestore-powered real-time messaging between trainers and clients. Clients can message assigned trainers plus the super trainer. Features include unread counts, smart timestamps, and conversation history. Messages update instantly with automatic read receipts.

### Session Management
Calendly integration handles appointment scheduling with automatic timezone conversion. Clients purchase session packages via Stripe, and trainers track attendance, payment history, and session notes. Live location sharing shows trainer ETA for in-person sessions.

### Progress Tracking
Comprehensive tracking of workouts, nutrition, body composition, and weight. Visual charts display trends over time. Trainers monitor client progress in real-time and can view detailed workout completion rates, meal logs, and body measurements.

### Onboarding System
New clients complete a health questionnaire covering medical history, fitness goals, dietary restrictions, and preferences. Trainers review this information before creating personalized programs. Clients can edit their onboarding data anytime from their profile.

## Setup

**Prerequisites**: Flutter 3.7.2+, Firebase CLI, Node.js 16+

**Quick Start**:
```bash
flutter pub get
flutterfire configure
firebase deploy --only firestore,functions,storage
flutter run
```

**Required Services**: Agora (video), Stripe (payments), Calendly (scheduling), Google AI (food recognition)

## Firebase Collections

```
users/                      # User profiles (trainer/client)
workoutTemplates/           # Shared workout templates
nutritionPlanTemplates/     # Shared meal plan templates
assignedWorkouts/           # Client workout assignments
nutritionPlans/             # Client nutrition plans
mealEntries/                # Client meal logs
bodyComp/                   # Body composition tracking
weightEntries/              # Weight tracking
sessions/                   # Training sessions
sessionPackages/            # Session credit packages
paymentHistory/             # Payment records
trainerVideos/              # Shared exercise video library
conversations/              # Messaging conversations
messages/                   # Chat messages
onboardingForms/            # Client onboarding data
video_calls/                # Video call sessions
tabata_timers/              # Synchronized workout timers
```

## Security & Architecture

**Authentication**: Firebase Auth with email verification and role-based access control  
**Database Rules**: Firestore security rules enforce trainer-client relationships and data ownership  
**Payments**: PCI-compliant Stripe integration with webhook validation  
**Data Protection**: Encrypted storage for health information and HIPAA-compliant handling  

**State Management**: Provider pattern for reactive UI updates  
**Real-time Sync**: Firestore snapshots for live data across all features  
**Timezone Handling**: UTC storage with automatic local conversion  
**Shared Resources**: All trainers access the same video gallery and templates