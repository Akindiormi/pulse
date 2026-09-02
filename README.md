# PULSE

PULSE is a daily-challenge mobile app built around small real-life actions, streaks, XP and achievements.

## Foundation

This repository contains the production-oriented Flutter foundation for PULSE: feature-based architecture, Riverpod state management, GoRouter navigation, Firebase-ready service boundaries, domain models, semantic theme tokens, motion-ready domain results, and test structure.

## Requirements

- Flutter 3.32+
- Dart 3.8+
- Android target API 36+
- A Firebase project for runtime authentication, Firestore, Messaging, Analytics and Crashlytics

## Local setup

1. Install Flutter and run `flutter doctor`.
2. Run `flutter pub get`.
3. Configure Firebase with FlutterFire for the Android application.
4. Add the generated Firebase configuration files locally; do not commit secrets or environment-specific credentials.
5. Run `flutter analyze` and `flutter test` locally.
6. Launch with `flutter run`.

## Architecture

`lib/core` contains cross-cutting infrastructure. `lib/models` contains stable domain models. `lib/features` owns feature presentation and state. `lib/services` contains business-oriented services with Firebase access kept behind repository/service boundaries. `lib/widgets` contains reusable presentation components.

Business logic emits typed activity results/events. Presentation decides how to animate them; no Rive or celebration animation logic is embedded in services.

## Firebase collections

- `users/{uid}`
- `users/{uid}/dailyChallenges/{yyyy-MM-dd}`
- `users/{uid}/activityDays/{yyyy-MM-dd}`
- `users/{uid}/achievements/{achievementId}`
- `challenges/{challengeId}`

## Verification

Flutter is not installed in the development environment used to create this repository foundation, so Flutter analysis, tests, and builds have **not** been claimed or marked as passing. Run them in a Flutter-enabled environment before treating the foundation as verified.
