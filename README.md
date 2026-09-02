# PULSE

PULSE is a daily-challenge mobile app built around small real-life actions, streaks, XP and achievements.

## Foundation

This repository contains the production-oriented Flutter foundation for PULSE: feature-based architecture, Riverpod state management, GoRouter navigation, Firebase-ready service boundaries, domain models, semantic theme tokens, motion-ready domain results, and test structure.

## Requirements

- Flutter 3.32+
- Dart 3.8+
- Android target API 36+
- A Firebase project for Authentication, Firestore, Cloud Messaging, Analytics and Crashlytics

## Local setup

1. Install Flutter and run `flutter doctor`.
2. Run `flutter pub get`.
3. Configure Firebase with FlutterFire for Android and generate `lib/firebase_options.dart` locally.
4. Enable the required Firebase Authentication providers.
5. Add Firebase Android configuration locally; credentials are intentionally excluded from source control.
6. Run `flutter analyze` and `flutter test` locally.
7. Launch with `flutter run`.

## Architecture

`lib/core` contains cross-cutting infrastructure. `lib/models` contains stable domain models. `lib/features` owns feature presentation and state. `lib/services` contains business-oriented services with Firebase access kept behind boundaries. `lib/widgets` contains reusable presentation components.

Business logic emits typed activity results/events. Presentation decides how to animate them; no Rive or celebration animation logic is embedded in services.

## Firebase collections

- `users/{uid}`
- `users/{uid}/dailyChallenges/{yyyy-MM-dd}`
- `users/{uid}/activityDays/{yyyy-MM-dd}`
- `users/{uid}/achievements/{achievementId}`
- `challenges/{challengeId}`

## Android

The foundation records API 36 as the minimum target for the production Android configuration. The official Flutter Android project files should be generated with the installed Flutter SDK (`flutter create . --platforms=android --project-name pulse --org com.pulse`) and then verified to target API 36+; generated platform files are not fabricated in this repository because Flutter is unavailable in the current environment.

## Verification status

Flutter is not installed in the environment used to create this foundation. Therefore `flutter analyze`, `flutter test`, dependency resolution, and Android builds **have not been run and are not claimed as passing**.
