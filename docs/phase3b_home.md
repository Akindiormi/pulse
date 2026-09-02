# Pulse Phase 3B — Home + Today’s Challenge

Phase 3B establishes the first real Pulse product experience: the Home screen and authoritative Today’s Challenge presentation.

## Data flow

```text
HomeScreen
  ↓
homeControllerProvider
  ↓
HomeController
  ├─ AuthService → authenticated UID
  ├─ UserRepository → profile/progress
  ├─ ChallengeService → getOrAssignDailyChallenge
  │       ↓
  │   TrustedChallengeBackend
  │       ↓
  │   Firebase Callable: getOrAssignDailyChallenge
  └─ ChallengeRepository → read-only challenge content
```

The Home UI never chooses a challenge locally and never creates a daily assignment.

## Progression

`HomeController` prepares the presentation model using the existing `XPService` for the next-level threshold and progress. The widget layer only presents those supplied values.

Authoritative XP, streak, level and achievement mutations remain behind the existing trusted completion architecture.

## States

Home supports:

- loading — skeleton foundations
- loaded — greeting, progression, challenge hero and restrained supporting content
- completed — completed hero state plus completion feedback
- unavailable — offline presentation with retry
- other backend errors — safe retry presentation

No local offline completion or reward behavior exists.

## Motion contract

The hero consumes the Phase 3A `PulseMotionState` vocabulary. Completion is represented as `completed`; future Challenge Detail/completion flows can return authoritative completion results to the Home controller without changing the backend contract.

The existing motion boundaries remain presentation-only. Rive, physics and custom celebration artwork are not introduced in Phase 3B.

## Navigation contract

The Home CTA navigates to `/challenge/:id`, which remains a foundation placeholder until the later Challenge Detail phase. No completion logic is duplicated in Home.

## Scope boundary

Phase 3B does not implement Challenge Detail, onboarding, authentication UI, achievements, profile, settings, community or advanced motion artwork.
