# Phase 3F — Settings + Notifications

## Experience

The `/settings` route is now a real, phone-first Pulse settings surface with three compact sections: Preferences, Account, and About.

Preferences contains daily challenge reminder, appearance, and reduced motion. Account links back to Profile and reuses the existing AuthService for sign-out and account deletion. About exposes the product description and app version.

## Persistence boundaries

- Appearance: local device preference through the existing ThemeController and `SharedPreferencesAsync`.
- Reduced motion: local device preference through `SharedPreferencesAsync`, applied to the existing `PulseMotionPolicy`.
- Daily reminder preference: authenticated user `notificationPreferences` through `UserRepository.updatePreferences`, with local copies of the selected reminder state/time for device continuity.
- Reminder time: persisted locally and included in the authenticated preference payload, but the current notification backend does not support scheduled delivery times.

## Notifications

The existing `NotificationService` abstraction remains the only notification boundary. Firebase Messaging is only accessed by `FirebaseNotificationService`.

The adapter exposes OS notification permission state. The current Firebase adapter intentionally does not pretend to schedule local daily notifications: its scheduling method reports `UnsupportedError` until a trusted backend/platform scheduling implementation exists. Settings surfaces this limitation rather than claiming a reminder is active when delivery cannot be scheduled.

## Appearance and motion

`ThemeController` remains the single theme controller and now persists System/Light/Dark selection. `PulseMotionPolicy` remains the single motion policy and additionally honors the user's reduced-motion preference while continuing to respect platform `MediaQuery.disableAnimations`.

## Account and legal boundaries

Sign-out and delete-account delegate to `AuthService`; Settings performs no direct Firebase Auth calls and no client-side Firestore collection deletion. The existing honest deletion limitation remains: authentication account deletion exists, while complete backend profile-data cleanup is not represented as complete.

No privacy or terms URL is exposed because the repository does not currently contain a configured legal destination. No URL was invented.

## Security

No authoritative progression fields are part of the Settings state or write payload. The only new backend user write is `notificationPreferences`, which is already an explicitly permitted profile preference field in the existing Firestore rules. No rules were weakened.

## Verification boundary

Flutter/Dart/Firebase CLI availability must be checked in the execution environment before claiming `pub get`, `analyze`, `test`, or Firebase runtime verification. Phase 3F tests are included but are not represented as passed unless actually executed.
