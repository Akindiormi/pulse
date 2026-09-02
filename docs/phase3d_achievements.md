# Phase 3D — Achievements + Progression

## Experience

`AchievementsScreen` is a phone-first collectible progression surface. It leads with authoritative level/XP progression, current and longest streak, and completed challenge count, then separates unlocked and locked achievements. Tapping a badge opens a detail presentation with its definition, state, reliable progress where available, unlock date when persisted, and the definition's XP reward.

## Authority

Achievement definitions remain in `achievement_definitions.dart`. The UI does not duplicate achievement rules or unlock them locally. `AchievementsController` reads the authenticated user and persisted achievement records through repositories. Achievement progress is presentation derived from authoritative user counters and the existing definition type/threshold; it is never used to unlock anything.

## Unlocks and events

`AchievementUnlockedEvent` remains the existing domain/event type. `AchievementsController.applyAchievementUnlocked` marks an event's ID as newly unlocked for presentation only. It does not mutate the user's authoritative unlocked set. A fresh controller load/refetch reads persisted backend state, so returning to the screen after completion reflects the authoritative collection.

## Motion

Achievement tiles expose locked, unlocked, newly-unlocked and milestone states through the existing `PulseAchievementMotionState`. XP/progression and streak surfaces expose existing progression/streak states. Motion uses `PulseMotionPolicy` and is intentionally restrained so custom Rive/physics artwork can attach later without owning business logic.

## Navigation

The shell's existing `/achievements` destination now opens the real screen. Home, Challenge Detail, profile placeholder and settings placeholder remain intact.

## Security boundary

No Phase 3D Flutter code writes authoritative progress, achievements, activities, daily assignments, XP, streaks or levels. The existing Firestore rules and trusted completion backend remain the source of truth.

## Verification boundary

The GitHub repository was inspected and the Phase 3D diff was reviewed. Flutter/Dart/Firebase CLI are not available in the execution environment, so `flutter pub get`, `flutter analyze`, `flutter test`, emulator testing and Firebase runtime verification were not run.
