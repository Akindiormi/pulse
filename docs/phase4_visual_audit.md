# Phase 4 Visual + Motion Audit

Base: `32cc0e69285809862c970694b491c7956cc5bce6`

## Scope reviewed

Reviewed the current presentation architecture for Splash, Onboarding, Authentication, Profile Setup (route-level implementation), Home, Challenge Detail, Achievements, Profile, Settings, plus the shared design, motion, feedback, state, button, card, hero, XP, streak and achievement components.

## Findings

### Visual system
- A usable Pulse token foundation already exists for color, spacing, radius and elevation.
- Typography is centralized in `AppTypography` and uses Inter, but screens mix `Theme.of(context).textTheme` and `AppTypography` directly. This creates small hierarchy/weight/line-height inconsistencies.
- Spacing is mostly tokenized, but some screens still use literal values and inconsistent horizontal padding patterns.
- Cards, buttons and rows are generally reusable, but some screens still use raw `FilledButton`, `OutlinedButton`, `TextButton`, `ListTile`, `Container` and ad-hoc chips instead of motion-ready Pulse primitives.
- Light/dark support is centralized, but some visual colors are still referenced directly in presentation code rather than semantic theme tokens.

### Motion
- A motion vocabulary already exists, but it is fragmented across several enums and is not yet a single product-level state/attachment contract.
- `PulseMotionSlot` and `PulseMotionBoundary` exist, but the boundary currently only lays out an optional overlay; it does not expose a typed visual attachment contract.
- Business events already exist separately from motion state, which is the correct direction. Phase 4 should make that separation more explicit rather than allowing widgets/controllers to become animation-specific.
- Home currently presents static states such as idle/completed. Challenge already has useful explicit phases. Achievements has newly-unlocked presentation state, but unlock/level-up visual sequencing needs clearer attachment points.
- Splash has no real branded motion slot beyond the current static mark and should never delay startup for decoration.

### Screen-specific opportunities
- **Splash:** branded visual slot, initialization status boundary, reduced-motion-safe transition; no artificial delay.
- **Onboarding:** illustration slot, page-transition slot, content/CTA sequencing, progress transition, accessible page announcement.
- **Auth:** coherent entry/form hierarchy, password affordance feedback, loading/error transition slots, provider boundary remains data-driven by actually supported methods.
- **Profile Setup:** consistent form/save feedback and completion transition slot.
- **Home:** strongest visual hierarchy should be greeting → streak → XP → Today’s Challenge; challenge is the primary motion surface. Streak and XP need scoped update states.
- **Challenge:** reveal/start/completion/reward sequencing should remain driven by authoritative completion output.
- **Achievements:** collection should support locked/unlocked/revealing/celebrating without local unlock logic; level-up needs a separate visual boundary.
- **Profile:** identity/stat/achievement sections can gain subtle entrance and save feedback without rebuilding the screen around animation.
- **Settings:** preference changes should have lightweight state feedback; avoid animating utility UI excessively.

### Accessibility and resilience
- Reduced-motion support already exists through `PulseMotionPolicy`, but new attachment points must consistently consult it.
- Existing semantic labels are useful, but some decorative visual slots should be explicitly excluded from semantics while state changes should be announced meaningfully.
- Loading/error/empty states exist and should be visually consistent rather than replaced with decorative animation.

## Phase 4 implementation direction

1. Strengthen shared design tokens and typography without changing the established Pulse identity.
2. Introduce a reusable, typed motion attachment/intent layer that is independent of business logic and can later host Rive/custom artwork.
3. Add scoped, lifecycle-safe motion state controllers where real state transitions benefit from them.
4. Add attachment points to the major screens/components without implementing placeholder Rive/Lottie artwork.
5. Improve shared controls and state surfaces so microinteractions can be attached consistently.
6. Keep all authoritative progression/auth/backend boundaries unchanged.
7. Add architecture-focused tests that do not depend on animation frame timing.

## Explicit non-goals

No Community, subscriptions, payments, challenge history, friend/social systems, new progression rules, backend authority changes, Firestore rule weakening, or unrelated feature work.

## Verification constraint

The repository is inspectable through GitHub, but Flutter/Dart/Firebase CLI availability must be checked before claiming `pub get`, analyze, tests, build, runtime, or performance verification.
