# PULSE Phase 2 application core

## Firebase setup

This repository intentionally does not contain generated Firebase configuration.

Before a connected run, configure the real Firebase project locally:

1. Run FlutterFire configuration for the real PULSE Firebase project and generate `firebase_options.dart` where the local project convention expects it.
2. Configure the Android Firebase app and add the real `google-services.json` locally.
3. Configure the iOS Firebase app and add the real `GoogleService-Info.plist` locally when iOS is enabled.
4. Enable Firebase Authentication providers required by the product.
5. Create the Firestore database and deploy `firestore.rules`.
6. Configure Analytics, Crashlytics and FCM in the Firebase console as appropriate.
7. Configure FCM delivery and the daily reminder schedule in trusted backend infrastructure. FCM itself is not a local scheduler.

Do not commit credentials, certificates, generated secrets, or private keys.

## Completion trust boundary

`CompleteChallenge` is deliberately separated from `FirestoreCompletionRepository`. The repository uses a Firestore transaction to read the user, daily assignment, challenge definition and deterministic activity key, and it writes the activity, progress and achievement records atomically when the rules permit it.

The current client Firestore rules intentionally deny writes to authoritative progress fields, activity history and achievement unlocks. This prevents a modified client from assigning itself XP, streaks, levels or achievements. Consequently, the production completion mutation must be moved behind a trusted backend/Cloud Function before Firebase-backed completion is enabled for untrusted clients.

The application use case remains usable with fakes for domain tests and is structured so the backend can reuse the same deterministic calculation and persistence contract.

## Daily assignment

The client-side service uses a stable UID + calendar-date selection and an idempotent Firestore create transaction. Existing assignments are never replaced. The trusted backend should eventually own assignment selection if the product requires adversarial resistance against clients choosing their preferred challenge.

Calendar keys are date-based rather than elapsed-24-hour windows. `CalendarService` can be injected with a fixed UTC offset for deterministic tests or a configured product timezone.

## Seed data

`challenge_seed_data.dart` contains 48 curated challenges across eight categories and four difficulty levels: six challenges per category, with 16 easy, 16 medium, 8 hard and 8 wild. It is seed content, not an automatic production write. Use a trusted/admin seed process to publish it to the `challenges` collection.
