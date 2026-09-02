# Pulse Phase 3C — Challenge Detail + Completion

Phase 3C turns the Phase 3B Home challenge CTA into the first complete Pulse action loop without moving any authoritative progression logic into Flutter.

## Data flow

```text
Home
  ↓ /challenge/:id
ChallengeDetailScreen
  ↓
ChallengeDetailController
  ├─ AuthService → authenticated state
  ├─ ChallengeService → trusted daily assignment
  └─ ChallengeRepository → read-only challenge content

Complete
  ↓
CompleteChallenge
  ↓
TrustedChallengeBackend
  ↓
Firebase Callable: completeChallenge
  ↓
authoritative XP / streak / level / achievements / activity
  ↓
CompletionResult
  ↓
UI state + Pulse motion events
  ↓
celebration
  ↓
Home refreshes from authoritative data
```

## Challenge identity

The route carries only the challenge ID. Before showing the detail experience, the controller obtains the current server-authoritative daily assignment and requires its challenge ID to match the route. This prevents the detail UI from presenting an arbitrary active challenge as the completion target.

Challenge content is read-only repository data parsed through the existing `Challenge` model. No challenge definitions are duplicated in the screen.

## Completion authority

The Flutter client calls the existing `CompleteChallenge` use case, which calls `TrustedChallengeBackend.completeChallenge()` with no client-controlled reward, UID, date, activity ID, challenge ID, streak, level or achievement fields. The optional idempotency key remains available through the existing backend contract but Phase 3C does not need to generate one.

The callable remains the authority for:

- completion eligibility
- duplicate completion detection
- XP awarded
- streak calculation
- longest streak
- level calculation
- achievement unlocks
- activity ID/date
- authoritative Firestore writes

## States

Challenge detail exposes:

- loading — skeleton foundations
- ready — challenge loaded, waiting to start
- starting — short tactile transition with duplicate-start protection
- active — user is doing the challenge
- completing — callable request is pending; no reward is shown yet
- completed — authoritative result is presented
- alreadyCompleted — no new reward is presented
- error — safe retry presentation
- unavailable — offline/unavailable presentation without fake completion

## Completion result presentation

Only values returned by `CompleteChallengeResult` are displayed. XP, streak, newly unlocked achievements and level-up are not recalculated in the UI. Level-up is shown only when `leveledUp` is true.

## Motion contract

Phase 3C extends the existing motion vocabulary with explicit challenge and completion states:

- Challenge: entering, idle, pressed, starting, loading, completing, completed, alreadyCompleted, unavailable, error
- Completion: pending, success, alreadyCompleted, error
- XP: unchanged, changed, xpGained, levelUp, full
- Streak: inactive, active, increased, maintained, broken, milestone
- Achievement: none, locked, unlocked, newlyUnlocked, milestone

The detail surface is wrapped in `PulseMotionBoundary`. Completion results are converted into UI motion state and existing `PulseEvent` instances from `CompleteChallenge` are dispatched through `PulseEventDispatcher`. No animation code owns business logic. Custom Rive/physics artwork remains an attachment concern for a later motion pass.

## Home integration

After completion or an already-completed response, the Home provider is invalidated before navigation to `/home`. Home therefore reloads profile/progression and the daily assignment through its existing architecture instead of receiving manually incremented XP/streak values from the detail screen.

## Scope boundary

Phase 3C does not implement achievements, profile, settings, community, onboarding, authentication UI, notifications UI or full challenge history.

Flutter/Dart/Firebase CLI availability is an environment concern; source-level implementation and repository inspection do not constitute Firebase runtime verification.
