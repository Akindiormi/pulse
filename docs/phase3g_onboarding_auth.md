# Phase 3G — Onboarding + Authentication UX

Base: `e0b7405e9222888dbc1fa616480d27e47a020e1a`

## First launch

`/splash` resolves application state in this order:

1. persisted onboarding completion
2. Firebase-backed auth state through `AuthService`
3. email verification state
4. authenticated user profile completeness
5. destination

Destinations are `/onboarding`, `/auth`, `/verify-email`, `/profile-setup`, or `/home`.

Onboarding completion is stored locally with `SharedPreferencesAsync` under `pulse.onboarding_completed`. Sign-out does not clear it.

## Onboarding

Three short screens:

- make today count
- one challenge. every day
- watch yourself grow

The user can skip before the final page or complete with `get started`. Motion uses the existing `PulseMotionPolicy`; no Rive/Lottie was introduced.

## Authentication

The current Firebase adapter safely exposes email sign-in and email account creation. Google and Apple methods exist in the `AuthService` contract but the repository adapter intentionally reports them as unsupported because provider wiring is not configured. Phone OTP is not exposed because there is no safe phone-auth boundary in the current architecture.

Forgot-password was added through the existing `AuthService` abstraction using Firebase Auth password reset.

No passwords, OTPs, tokens, or credentials are persisted or logged.

## Verification

New email accounts remain in `authenticatedUnverified` state. Pulse sends Firebase's native verification email, provides resend with cooldown, and can reload the current Firebase user to check `emailVerified` without restarting the app.

## Profile setup

After authentication, startup checks the existing `UserModel`. Missing display name routes to profile setup. The setup screen persists only the existing supported identity field through `UserRepository.createOrUpdateUser`. The existing repository behavior creates the initial username from the display name; no new username-uniqueness or post-creation username mutation path was invented.

## Error and recovery model

`AppError` and `ErrorMessageMapper` provide one safe presentation model for authentication failures. Known Firebase auth failures are translated into short user-facing messages; raw exception names are not displayed.

Recoverable flows include validation, retryable network/auth failures, password reset, verification resend/check, duplicate-submission prevention, and session-expiry routing.

## Analytics

Added funnel events:

- `onboarding_started`
- `onboarding_completed`
- `onboarding_skipped`
- `auth_screen_viewed` (available in analytics boundary)
- `sign_up_started`
- `sign_up_completed`
- `sign_in_started`
- `sign_in_completed`
- `auth_failed`
- `google_sign_in_started/completed` (boundary-ready; provider unavailable)
- `apple_sign_in_started/completed` (boundary-ready; provider unavailable)
- `email_verification_sent`
- `email_verification_completed`
- `profile_setup_started`
- `profile_setup_completed`

No credentials or unnecessary personal data are included.

## Security

Phase 3G does not modify progression authority. XP, streak, level, achievement, activity, challenge completion, and trusted backend security remain outside client authority. Firestore rules were not weakened. Account deletion still uses the existing `AuthService.deleteAccount()` boundary; complete backend profile cleanup remains the existing limitation.

## Verification status

Flutter/Dart/Firebase CLIs are not available in the execution environment, so `flutter pub get`, `flutter analyze`, `flutter test`, emulator tests, device authentication, and runtime provider testing were not run. Repository changes were inspected through GitHub only.

## Out of scope

Community, social feed/friends, challenge history, subscriptions, payments, notification campaigns, and advanced profile customization remain unbuilt.
