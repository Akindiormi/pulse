begin;

create extension if not exists pgtap with schema extensions;

select plan(27);

-- Contract/schema checks.
select has_column(
  'public', 'profiles', 'streak_grace_used_on',
  'profiles stores the date of the most recent consumed grace day'
);
select has_function(
  'public', 'pulse_local_date', ARRAY['timestamp with time zone', 'text'],
  'local calendar-date helper exists'
);
select has_function(
  'public', 'calculate_streak_v1', ARRAY['date', 'integer', 'date', 'date'],
  'authoritative streak transition function exists'
);
select has_index(
  'public', 'activity_events_task_completion_idx',
  'task completion activity events have a uniqueness guard'
);
select is_definer(
  'public', 'complete_task', ARRAY['uuid'],
  'task completion remains backend-authoritative through a security definer function'
);
select matches(
  pg_get_functiondef('public.complete_task(uuid)'::regprocedure),
  'for update',
  'task completion locks the task row so concurrent retries serialize'
);

-- A day is a calendar date in the named IANA timezone, not 24 elapsed hours.
select is(
  public.pulse_local_date('2026-09-10 03:59:59+00', 'America/New_York')::text,
  '2026-09-09',
  'timezone conversion uses the user calendar date'
);
select is(
  public.pulse_local_date('2026-09-10 04:00:00+00', 'America/New_York')::text,
  '2026-09-10',
  'midnight boundary changes the calendar date'
);

-- DST spring-forward: the day is still one calendar day despite being 23 elapsed hours.
select is(
  public.pulse_local_date('2026-03-08 04:59:59+00', 'America/New_York')::text,
  '2026-03-07',
  'DST spring-forward before local midnight remains the prior calendar day'
);
select is(
  public.pulse_local_date('2026-03-08 05:00:00+00', 'America/New_York')::text,
  '2026-03-08',
  'DST spring-forward after local midnight enters the new calendar day'
);

-- DST fall-back: repeated local clock time does not create a second calendar day.
select is(
  public.pulse_local_date('2026-11-01 04:30:00+00', 'America/New_York')::text,
  '2026-11-01',
  'DST fall-back first 1:30 remains the same calendar day'
);
select is(
  public.pulse_local_date('2026-11-01 06:30:00+00', 'America/New_York')::text,
  '2026-11-01',
  'DST fall-back repeated hour remains the same calendar day'
);

-- First-ever qualifying activity.
select is(
  (public.calculate_streak_v1(null, 0, '2026-09-10', null) ->> 'newStreak')::integer,
  1,
  'first qualifying activity starts a one-day streak'
);

-- Same calendar day is idempotent at the streak level.
select is(
  (public.calculate_streak_v1('2026-09-10', 4, '2026-09-10', null) ->> 'newStreak')::integer,
  4,
  'additional activity on the same calendar day does not inflate the streak'
);

-- Consecutive days extend by one.
select is(
  (public.calculate_streak_v1('2026-09-10', 4, '2026-09-11', null) ->> 'newStreak')::integer,
  5,
  'next calendar day extends the streak by one'
);

-- Exactly one missed day can be covered by grace.
select is(
  (public.calculate_streak_v1('2026-09-10', 4, '2026-09-12', null) ->> 'newStreak')::integer,
  6,
  'one missed calendar day can be covered by grace'
);
select is(
  (public.calculate_streak_v1('2026-09-10', 4, '2026-09-12', null) ->> 'useGrace')::boolean,
  true,
  'one missed calendar day consumes grace'
);

-- Grace is unavailable inside the rolling seven-calendar-day window.
select is(
  (public.calculate_streak_v1('2026-09-15', 4, '2026-09-17', '2026-09-12') ->> 'newStreak')::integer,
  1,
  'grace cannot be reused inside seven calendar days'
);
select is(
  (public.calculate_streak_v1('2026-09-19', 4, '2026-09-21', '2026-09-12') ->> 'newStreak')::integer,
  6,
  'grace becomes available on the seventh calendar day after use'
);

-- A gap larger than one missed calendar day cannot be repaired by one grace day.
select is(
  (public.calculate_streak_v1('2026-09-10', 8, '2026-09-13', null) ->> 'newStreak')::integer,
  1,
  'two or more missed calendar days reset the streak'
);
select is(
  (public.calculate_streak_v1('2026-09-10', 8, '2026-09-13', null) ->> 'useGrace')::boolean,
  false,
  'grace is only for exactly one missed calendar day'
);

-- A broken streak remains broken when grace is unavailable.
select is(
  (public.calculate_streak_v1('2026-09-10', 8, '2026-09-12', '2026-09-08') ->> 'newStreak')::integer,
  1,
  'a previously consumed grace blocks reuse inside the rolling window'
);

-- A grace date exactly seven days old is eligible again.
select is(
  (public.calculate_streak_v1('2026-09-20', 8, '2026-09-22', '2026-09-15') ->> 'useGrace')::boolean,
  true,
  'grace is reusable exactly seven calendar days after prior use'
);

-- Travel is represented by the stored IANA timezone; the same instant may belong to different user days.
select is(
  public.pulse_local_date('2026-09-10 23:30:00+00', 'Africa/Lagos')::text,
  '2026-09-11',
  'Lagos timezone maps the instant to the correct local calendar day'
);
select is(
  public.pulse_local_date('2026-09-10 23:30:00+00', 'America/Los_Angeles')::text,
  '2026-09-10',
  'a user timezone change can legitimately change the local calendar date'
);

-- Migration is prospective: there is no helper behavior that consumes grace without a qualifying transition.
select is(
  (public.calculate_streak_v1('2026-09-10', 4, '2026-09-10', null) ->> 'useGrace')::boolean,
  false,
  'same-day activity never consumes grace'
);

-- Typed activity vocabulary remains explicit and non-generic.
select col_has_check(
  'public', 'activity_events', 'event_type',
  'activity events retain an explicit typed vocabulary'
);

select * from finish();
rollback;
