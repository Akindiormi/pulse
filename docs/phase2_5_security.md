# Phase 2.5 — authoritative completion security

## Client writes blocked by Firestore rules

The client can read its own user document, daily assignment documents, activity history, activity-day summaries, and achievements. Authenticated clients can read challenge content.

The client is explicitly blocked from:

- creating, updating, or deleting `users/{uid}/dailyChallenges/{date}` documents
- writing `users/{uid}/activities/{activityId}`
- writing `users/{uid}/activityDays/{date}`
- writing `users/{uid}/achievements/{achievementId}`
- directly changing authoritative progress fields on `users/{uid}`: `totalActivities`, `currentStreak`, `longestStreak`, `xp`, `level`, `lastActivityDate`, `completedCategories`, and `unlockedAchievements`
- writing `challenges/{challengeId}`
- deleting user documents

User creation is restricted to a signed-in owner and requires zero progress, level 1, and empty achievement/category state. Profile updates are limited to profile/preferences fields.

## Trusted completion contract

The production completion path is the `completeChallenge` callable Cloud Function.

The callable accepts only an optional `idempotencyKey`; it does not accept a user ID, challenge ID, date, XP amount, streak value, level, achievement list, or completion timestamp from the client. Authentication supplies the UID. The function derives the current date from server UTC time.

The function atomically:

1. reads the user and today's assignment
2. creates a server-sourced assignment if the assignment is missing or legacy/untrusted
3. verifies the assigned challenge is active
4. derives the activity ID as `{serverDate}-{challengeId}`
5. checks the activity document for duplicate completion
6. calculates XP, level, streak, category history, and achievement unlocks on the server
7. creates the activity and achievement records
8. updates authoritative user progress
9. marks the assignment completed

All authoritative writes occur in one Firestore transaction. Firestore Security Rules are not the authorization boundary for Admin SDK writes; the callable's authentication/App Check checks and server-side validation are the boundary.

## Daily assignment

Daily assignment is backend-authoritative. `getOrAssignDailyChallenge` chooses from active challenges sorted by document ID and uses the same stable date-based selection for a given server UTC date. Client-side assignment creation is disabled.

Legacy assignment documents that lack `source: 'server'` are treated as untrusted and replaced by the backend with a server-selected assignment before completion.

## Idempotency

The authoritative idempotency key is the server-derived activity document ID, not a client-provided ID. A repeated request for the same user/date/challenge finds either a completed assignment or an existing activity and returns `alreadyCompleted: true` without awarding additional XP.

The optional request `idempotencyKey` is accepted for retry correlation but is deliberately not used as the activity document ID, so a malicious client cannot create multiple reward records by changing it.

## Time model

The trusted backend currently uses UTC calendar days. This is intentional: a client cannot submit a fabricated date or manipulate streak progression by changing its device clock. User timezone/profile preferences are not used as the authoritative completion date yet.

If product requirements later require local-calendar-day streaks, timezone handling must be moved into the trusted backend and protected against rapid timezone changes; it must not return to client-authoritative date calculation.

## App Check

The callable functions use Firebase App Check enforcement. The Flutter client integration now reaches the functions through the official callable SDK boundary, but release builds still require the App Check SDK/provider configuration appropriate to the target platforms before callable requests can succeed in a deployed environment.

## Verification status

Repository-level inspection confirms the rules, backend, Flutter callable abstraction, dependency injection, and application paths described above. The repository environment does not contain the Flutter/Dart runtime, and no Firebase project/emulator credentials are available through this GitHub inspection environment. Therefore no claim is made that Firestore Rules evaluation, callable authentication, App Check enforcement, transaction retries, or deployed Firebase behavior has been runtime-tested.

The Node backend includes pure security/domain tests under `functions/test/`; these require `npm install` in `functions/` and were not claimed as executed in this environment.

## Remaining production work

- install Flutter dependencies and run `flutter analyze` / `flutter test`
- install Functions dependencies and run `npm test`
- deploy functions to the intended Firebase project
- configure the Flutter App Check SDK/provider for the Android/iOS release builds
- run Firestore Rules Emulator tests covering allowed reads/profile writes and denied authoritative writes
- run deployed callable tests covering authentication, App Check, transaction retry/idempotency, and error mapping
- seed/verify challenge documents in the Firebase project
- verify the Firebase project is on a billing plan that supports Cloud Functions deployment
