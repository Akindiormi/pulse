# Phase 6 — Premium Motion & Interaction

Phase 6 builds additively on the Phase 5 Rive boundary. The current product has no `.riv` artwork, so Flutter-native motion is the active presentation implementation and Rive remains an optional future adapter.

## Architecture

Authoritative application state → `PulseMotionIntent` → `PulseMotionAttachment` / `PulseMotionBoundaryV2` → presentation animation.

Motion components do not calculate XP, streaks, achievements, levels, or completion and do not write backend state.

## Motion shipped

- reusable attachment presentation with short entrance/state transitions
- scoped staggered entrances for Home
- tactile press scale for buttons and interactive cards
- completion celebration with a small bounded custom-paint burst
- level-up celebration reusing the same lightweight primitive
- streak change/milestone emphasis with a disposable controller
- existing XP progress tween retained and governed by motion policy
- existing onboarding, profile, achievements, settings and navigation attachment boundaries now benefit from the shared motion presentation layer
- route relationships remain distinct through GoRouter custom transitions

## Reduced motion

`PulseMotionPolicy.isReducedMotion(context)` remains the single policy. It combines the existing user preference with Flutter's `MediaQuery.disableAnimations`. Reduced motion removes decorative particles, spring/scale emphasis and large movement while preserving state changes, readable text and functionality.

## Rive

No fake `.riv` files were created. Phase 5 `PulseRiveMotionHost`, `PulseRiveAttachment`, asset constants and reserved asset directories remain untouched and available when real designer assets are supplied.

## Accessibility

Motion is never the only success/error/completion signal. Existing semantic labels/live regions remain on completion, achievement, profile and progression surfaces. Interactive cards/buttons preserve semantic button behavior and 48px-class touch targets.

## Lifecycle/performance

Animation controllers are scoped to the widgets that use them and disposed in `dispose()`. There are no infinite decorative loops, permanent listeners, or timers. Celebration particles are limited to ten lightweight shapes and run for a short fixed duration. No 60fps claim is made without device measurement.

## Verification boundary

GitHub history and source changes can be inspected remotely. Flutter/Dart/Firebase tooling availability must be checked before claiming `pub get`, analyze, tests, builds, runtime behavior or visual/performance verification.
