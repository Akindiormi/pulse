# PULSE Phase 7A — Release Integrity

## Scope

Phase 7A fixes only confirmed release-integrity blockers from the Phase 7A-1 preflight:

- shell import/reference errors
- partial profile update field preservation
- trusted account-data deletion
- production challenge seeding

No Firebase deployment is performed by this phase.

## Account deletion

The client calls the trusted `deleteAccountData` callable while the Firebase Auth user is still authenticated. The callable derives the UID from `request.auth.uid` and uses Admin SDK `recursiveDelete` on `users/{uid}` only.

This removes the user document and all subcollections currently beneath it, including:

- `dailyChallenges/*`
- `activities/*`
- `activityDays/*`
- `achievements/*`

Global `challenges/*` documents are not targeted.

The client Firestore rules continue to deny direct deletion. The client deletes the Firebase Auth account only after the trusted Firestore cleanup succeeds. If Auth deletion fails after cleanup, the authenticated account may temporarily remain without application data; retrying the same deletion workflow is safe because the cleanup operation is idempotent.

Firestore data cleanup and Firebase Auth deletion are not a single transaction and must not be described as atomic.

## Challenge seeding

`functions/scripts/seed_challenges.js` reads `lib/features/challenges/data/challenge_seed_data.dart` directly and parses the existing `_challenge(...)` records. It validates the authoritative 48-record contract: eight categories with six challenges each, distributed as 16 easy, 16 medium, 8 hard and 8 wild.

The command upserts each record into `challenges/{challengeId}` with `merge: true`. Existing IDs are updated, repeated runs are safe, and unrelated challenge documents are not deleted. Repeating the seed operation over the 48-record source therefore performs 96 writes.

Run from the repository with trusted Firebase Admin credentials and the intended Firebase project selected:

```text
cd functions
npm install
npm run seed:challenges
```

The script uses Firebase Admin Application Default Credentials. Credentials and generated secrets must remain outside the repository. The script does not deploy Functions or Firestore rules.

## Verification boundary

Flutter/Dart checks require Flutter/Dart tooling and a configured local Flutter project. Functions tests require the Functions dependencies to be installed.

No deployment is part of Phase 7A.
