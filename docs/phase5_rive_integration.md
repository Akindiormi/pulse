# Phase 5 — Rive + Premium Motion Integration

## Contract

Phase 4's motion boundary remains:

`business/application state → PulseMotionIntent + state → PulseMotionAttachment → visual`

Rive is an optional visual implementation behind that boundary:

`PulseMotionAttachmentData → PulseRiveAttachment → PulseRiveMotionHost → Rive`

Business services, repositories, and trusted backend code never receive a Rive controller.

## Runtime

`rive: ^0.14.11` is used. This is the current stable Rive Flutter runtime at implementation time and supports the repository's Dart 3.8 / Flutter 3.32 constraints. Rive's current API uses `RiveWidget`, `RiveWidgetBuilder`, `RiveWidgetController`, and `StateMachine` inputs.

Rive initialization remains lazy. Startup does not await Rive initialization, so decorative motion cannot delay the startup resolver.

## Assets

Canonical paths are defined in `PulseRiveAssets`:

- splash
- onboarding
- auth
- challenge
- progression
- achievements
- profile
- navigation

No production `.riv` artwork was supplied in the repository for Phase 5. The folders therefore contain documentation placeholders only. No generic animation was substituted for the user's artwork.

## Safe integration

`PulseRiveMotionHost` handles loading through `RiveWidgetBuilder`. Missing assets, artboards, state machines, and inputs fall back to the existing Flutter UI. Trigger, boolean, and number input access is guarded and returns a safe result instead of throwing into product UI.

## Reduced motion

`PulseMotionPolicy.isReducedMotion(context)` is checked before decorative Rive content is rendered. This respects both the platform accessibility setting and Pulse's user preference. The legacy `PulseMotionBoundary` remains policy-aware.

## Lifecycle/performance

Each host owns its `FileLoader` and disposes it when removed. The presentation adapter pauses the Rive controller before disposal. Rive is not loaded when reduced motion is active or when the asset path is empty.

No shared Rive panel, sound, haptic dependency, or additional animation library was introduced without actual supplied assets/requirements.

## Existing screen boundaries

Splash, onboarding, auth, profile setup, Home, challenge, achievements, profile, settings, and navigation already expose Phase 4 motion attachment points. Phase 5 adds the reusable Rive implementation behind those points; screens continue using their functional Flutter fallbacks until matching user-owned `.riv` files are supplied.

## Verification

Flutter, Dart, and Firebase CLI executables are unavailable in the current environment, so dependency resolution, `flutter analyze`, `flutter test`, platform builds, device runtime, Rive runtime, and frame-rate measurements were not claimed as verified.
