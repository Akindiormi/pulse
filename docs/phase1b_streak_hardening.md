# Slice 1B — Streak Hardening

## Authoritative rules

### What defines a day?

A Pulse day is the **calendar date in the user's IANA timezone stored on `profiles.timezone`**.

- The timezone is initialized from the device timezone.
- If the device timezone changes, the stored timezone may be updated for future activity.
- If no timezone is available, UTC is the deterministic fallback.
- Historical activity dates are not recalculated when the timezone changes.
- Streak logic compares calendar dates, never elapsed hours.

This means daylight-saving transitions do not create or remove a streak day. A 23-hour or 25-hour local day is still exactly one calendar day.

### Migration v1

The existing streak state is preserved exactly as-is.

- Historical activity is not recalculated.
- The migration itself is not an activity.
- The migration does not reset, extend, or consume grace.
- The first new qualifying activity after migration uses the preserved state as its starting point.

### Grace semantics

Pulse has **one grace day per rolling 7-calendar-day window**.

- Grace covers exactly one missed calendar day.
- If the previous qualifying activity was exactly two calendar dates ago, a qualifying activity today may use grace and continue the streak.
- A gap of three or more calendar dates cannot be repaired by one grace day.
- After grace is consumed on date `D`, another grace cannot be consumed until `D + 7`.
- Grace does not create an activity event.
- Same-day duplicate activity never consumes grace.

### Duplicate and concurrent completion

Task completion is backend-authoritative.

- The task row is locked with `FOR UPDATE` before completion.
- A completed task returns `alreadyCompleted` and awards zero XP on retry.
- `activity_events` has a unique guard for `(user_id, event_type, entity_id)` for `task_completed` events.
- Therefore a flaky network retry cannot award XP or create a second meaningful activity for the same task.

## Test matrix

1. Explicit timezone calendar-date boundaries.
2. DST spring-forward.
3. DST fall-back.
4. First qualifying activity.
5. Same-day duplicate behavior.
6. Consecutive calendar days.
7. One missed day with grace.
8. Grace unavailable inside the rolling seven-day window.
9. Grace available exactly seven days later.
10. Multiple missed days reset the streak.
11. Stored timezone differences for travel.
12. Backend security-definer completion path.
13. Task-row lock for concurrent retries.
14. Unique task-completion event guard.
15. Explicit typed activity vocabulary.

## Architectural constraint

Meaningful activity remains a closed typed vocabulary:

- `task_completed`
- `focus_completed`
- `milestone_completed`
- `project_completed`

Do not introduce a generic arbitrary `record_activity(string)` endpoint.
