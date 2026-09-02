# Pulse Phase 3A UI foundation

Phase 3A establishes the visual language, reusable UI primitives, app shell, and motion attachment boundaries without implementing product screens.

## Design tokens

- `lib/core/design/pulse_tokens.dart` — color, spacing, radius, and elevation primitives.
- `lib/core/theme/app_colors.dart` — compatibility surface backed by Pulse tokens.
- `lib/core/theme/app_theme.dart` — intentional light/dark Material themes and typography.

Light background is `#FAF7F2`, dark background is `#0E0E10`, and the primary accent is `#FF6B4A`.

## Reusable UI

- `PulseButton` / `PulseIconButton`
- `PulseCard` / `PulseHeroCard`
- `PulseHeroChallenge`
- `PulseXpProgress`
- `PulseStreak`
- `PulseAchievementBadge`
- `PulsePageLoading`, `PulseCardLoading`, `PulseInlineLoading`
- `PulseErrorState`, `PulseEmptyState`, `PulseOfflineState`
- `PulseCompletionSurface`, `PulseLevelUpSurface`

Presentation widgets accept supplied values/models. They do not calculate XP, streaks, achievements, challenge assignment, or backend state.

## Motion contract

`lib/core/motion/pulse_motion_state.dart` defines the interaction vocabulary used by the UI layer:

- hero: entering, idle, pressed, loading, completing, completed, unavailable, error
- XP: initial, changed, XP gained, level-up, full
- streak: inactive, active, increased, maintained, broken, milestone
- achievement: locked, unlocked, newly unlocked, milestone
- celebration events: completion, XP gain, streak update, achievement unlock, level-up

`PulseMotionBoundary` and `PulseMotionSlot` are intentionally small attachment points for future Rive, physics, or Flutter-native motion. They do not own business logic.

The UI establishes basic tactile feedback where appropriate (button press, selected navigation state, restrained progress transition). Custom motion artwork remains outside Phase 3A.

`PulseMotionPolicy` provides a reduced-motion hook through the platform accessibility setting.

## App shell

`lib/features/shell/presentation/pulse_shell.dart` provides the reusable phone shell and tactile bottom navigation for:

- Home
- Challenges
- Achievements
- Profile

Settings remains a routed secondary destination. Splash, onboarding, auth, and challenge detail remain outside the shell where their later product phases can own the full experience.

`lib/routing/app_router.dart` keeps GoRouter and adds the shell without replacing the routing architecture.

## Domain boundary

The existing Phase 2 / 2.5 / 2.75 architecture remains the source of truth. UI components consume values/models supplied by controllers/providers/application services. No Firebase call, XP calculation, streak calculation, achievement rule, challenge assignment, or completion mutation is implemented in the UI foundation.

## Verification note

The repository environment used for this phase does not have Flutter/Dart/Firebase CLI available. Flutter tests, analyze, build, and emulator verification therefore must be run in a Flutter-capable environment before release. Static repository inspection is not a substitute for those runtime checks.
