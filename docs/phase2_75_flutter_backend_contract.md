# Phase 2.75 — Flutter ↔ trusted backend contract

## Production flow

```text
Flutter UI
  ↓
CompleteChallenge / ChallengeService
  ↓
TrustedChallengeBackend
  ↓
Firebase callable function
  ↓
Firestore transaction
```

The Flutter application does not perform authoritative completion or daily-assignment writes.

## Callable: `getOrAssignDailyChallenge`

Authentication: required.

Request:

```json
{}
```

No client-controlled UID, date, challenge ID, reward, completion state, or timestamp is accepted.

Response:

```json
{
  "date": "YYYY-MM-DD",
  "challengeId": "string",
  "completed": false,
  "assignedAt": "server timestamp"
}
```

The date is the backend's UTC calendar date. The server chooses the challenge from active challenge documents. An existing `source: "server"` assignment is returned unchanged; a missing or legacy/untrusted assignment is replaced by the backend.

## Callable: `completeChallenge`

Authentication: required. Firebase App Check is enforced by the deployed function configuration.

Request:

```json
{}
```

or, for retry correlation only:

```json
{"idempotencyKey":"opaque-client-correlation-value"}
```

The client must never send UID, challenge ID, date, XP, streak, level, achievement list, activity ID, reward amount, or completion timestamp.

Response for a new completion:

```json
{
  "completed": true,
  "alreadyCompleted": false,
  "challengeId": "string",
  "xpAwarded": 35,
  "challengeXP": 10,
  "achievementXP": 25,
  "previousXP": 0,
  "currentXP": 35,
  "previousStreak": 0,
  "currentStreak": 1,
  "longestStreak": 1,
  "previousLevel": 1,
  "newLevel": 1,
  "leveledUp": false,
  "newAchievements": ["FIRST_STEP"]
}
```

Response for a duplicate/retry after the completion already exists contains `completed: false`, `alreadyCompleted: true`, `xpAwarded: 0`, the current authoritative progress snapshot, and no new achievements.

## Error mapping

Firebase callable errors are mapped into `TrustedBackendException`:

- `unauthenticated` → `unauthenticated`
- `permission-denied` → `permissionDenied`
- `not-found` → `notFound`
- `failed-precondition` → `failedPrecondition`
- `invalid-argument` → `invalidArgument`
- `unavailable` / `deadline-exceeded` → `unavailable`
- `already-exists` → `alreadyCompleted`
- other/internal failures → `internal`

Raw backend messages are not surfaced to the application layer.

## Idempotency and retry

The authoritative completion key is the backend-derived activity document ID:

`{serverDate}-{challengeId}`

The optional client `idempotencyKey` is not used as a reward-record identifier. Therefore a retry after a lost response cannot create another activity or reward. Flutter never awards XP locally while waiting for or after a failed callable request.

## Flutter authentication boundary

`FirebaseCallableChallengeBackend` checks the existing `AuthService` before protected calls. It does not create another authentication system and does not transmit the Auth UID as a request authority field. The Firebase callable SDK supplies the authenticated Firebase identity to the function.

## Firestore boundary

Flutter-side Firestore repositories are read-only for completion-related data. Daily assignment creation, activity creation, achievement creation, authoritative progress mutation, and completion state mutation are backend-only operations. Firestore rules remain unchanged by the Flutter integration.

## Runtime verification

This contract is repository-level and static. Runtime verification still requires the Flutter/Dart toolchain, installed packages, a configured Firebase project, App Check configuration, and Firebase Emulator/deployed-function execution. No runtime Firebase behavior is claimed as verified by this repository-only integration pass.
