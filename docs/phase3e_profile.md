# Phase 3E — Profile + Identity

## Scope

Phase 3E adds the real `/profile` experience only. It does not add Settings, Notifications UI, Community, Onboarding, Authentication UI, Challenge History, payment/subscription features, or advanced account management.

## Identity authority

Profile reads the existing `UserModel` through `UserRepository` using the authenticated UID supplied by `AuthService`. It presents display name, username when persisted, and photo URL when available. No raw Firebase user object, UID, token, password, or provider credential is displayed.

The profile photo is presentation-only in this phase. There is no new Storage/upload system. When no usable photo URL exists, the UI derives tasteful initials from the display name.

## Editing

Only `displayName` is editable because that field is already supported by the existing `UserRepository.createOrUpdateUser` contract and existing Firestore profile update rule. Username editing and avatar upload are intentionally not added because there is no dedicated safe application/backend flow for them in the current architecture.

The edit flow is idle → editing → saving → saved/error, prevents duplicate saves at the UI/controller boundary, and refetches the profile after persistence. Widgets do not write Firestore directly.

## Progression

XP, level, current streak, longest streak, total activities, completed categories, and unlocked achievements are read from existing authoritative `UserModel`/achievement repository state. Profile does not calculate or mutate rewards, streaks, completion history, or achievements. XP progress is delegated to the existing `XPService`.

## Achievements

Profile shows a compact highlight of persisted achievement records and routes to the existing `/achievements` screen. It does not recreate achievement definitions or unlock logic.

## Account actions

Sign out delegates to `AuthService.signOut()`. Authentication state remains the router/auth boundary; Profile does not fake authentication state.

Delete account requires explicit confirmation and delegates to `AuthService.deleteAccount()`. The current Firebase auth abstraction deletes the authenticated account, but Firestore profile/collection cleanup is not implemented as a complete backend deletion workflow. The UI explicitly discloses this limitation and does not perform unsafe client-side collection deletion.

## Motion

`PulseProfileMotionState` provides identity/edit attachment states: entering, idle, pressed, editing, saving, saved, error. Existing progress, streak, and achievement motion vocabularies are reused. No Rive, physics, or custom artwork was introduced.

## Security regression

No Firestore rules were weakened. No profile UI writes authoritative progression fields. The existing `/users/{uid}` update rule remains restricted to profile/preference fields, while authoritative completion/activity/achievement paths remain protected by the existing rules/backend boundary.

## Verification boundary

GitHub repository inspection and source-level review were performed. Flutter, Dart, and Firebase CLIs are unavailable in the execution environment, so `flutter pub get`, `flutter analyze`, `flutter test`, emulator/runtime checks, and Firebase runtime verification were not performed.
