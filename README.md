# Merge Fitness Companion App

A mobile application for fitness clients to track workouts, receive reminders, log meals, and monitor body composition, with future expansion for self-serve users.

## Tech Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Firebase (Firestore, Auth, Cloud Functions)
- **Notifications:** Firebase Cloud Messaging
- **Media Storage:** Firebase Storage
- **Crash Reporting:** Firebase Crashlytics
- **Analytics:** Firebase Analytics
- **Maps & Location:** Google Maps plugin for Flutter

## Project Features

### Phase 1 MVP

1. **Auth & Onboarding**
   - Email/password login
   - Onboarding quiz
   - Role-based UI

2. **Workout Program Assignment**
   - Trainer uploads plan
   - Client sees daily workout with sets/reps/media

3. **Workout Logging & Check-in**
   - Client marks workout complete
   - 7pm push notification if not done

4. **Body Composition Tracking**
   - Log weight, BF%, lean mass
   - Line charts visualization

5. **Food Logging & Smart Swaps**
   - Log meals via photo/upload
   - Get trainer-approved healthy alternatives
   - AI-powered food recognition to automatically determine nutritional information

6. **Schedule & Reminders**
   - Book via Calendly
   - Calendar invite + 15 min push reminder

7. **Trainer ETA Map Tracker**
   - Live ETA map pin sharing

## Features

### AI Food Recognition
The app includes an AI-powered food recognition feature that allows users to take a photo of their meal to automatically analyze and populate nutritional information. See [README_FOOD_RECOGNITION.md](README_FOOD_RECOGNITION.md) for setup and usage instructions.

## Project Setup

### Prerequisites

- Flutter SDK (2.x or later)
- Dart SDK (2.15.x or later)
- Firebase account
- Android Studio or Xcode for deployment

### Getting Started

1. Clone the repository
   ```
   git clone https://github.com/yourusername/merge_fitness.git
   cd merge_fitness
   ```

2. Install dependencies
   ```
   flutter pub get
   ```

3. Configure Firebase
   ```
   flutterfire configure
   ```

4. Run the app
   ```
   flutter run
   ```

## Directory Structure

```
lib/
├── main.dart
├── models/
│   ├── user_model.dart
│   ├── workout_model.dart
│   ├── body_comp_model.dart
│   ├── food_log_model.dart
│   ├── session_model.dart
├── services/
│   ├── auth_service.dart
│   ├── workout_service.dart
│   ├── firestore_service.dart
│   ├── notification_service.dart
├── screens/
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── workout_screen.dart
│   ├── progress_screen.dart
│   ├── schedule_screen.dart
│   └── trainer_dashboard.dart
├── widgets/
│   ├── workout_card.dart
│   ├── body_comp_chart.dart
│   └── food_logger.dart
```

## Firestore Data Structure

```
users/{uid}
  - email, role, height, dob, goals

programs/{programId}
  - trainerId, title, weeks: [ { day: "Mon", exercises: [ { name, sets, reps, videoUrl } ] } ]

workouts/{workoutInstanceId}
  - userId, programId, date, completedAt, notes

bodyComp/{uid}/{entryId}
  - date, weight, bodyFatPct, leanMassKg

foodLogs/{logId}
  - userId, timestamp, mealType, photoUrl, suggestedSwapId

sessions/{sessionId}
  - clientId, time, status, calendarUrl
```

## Personas

- **Trainer (BJ):** Assigns programs, tracks client progress, sends reminders
- **Client:** Follows workouts, logs data, books sessions
- **Future Self-Serve User:** Uses library-based workouts and premium features

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is proprietary and confidential.
