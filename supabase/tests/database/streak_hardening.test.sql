begin;

create extension if not exists pgtap with schema extensions;

select plan(27);

-- Schema and backend-authority checks.
select has_column(
  'public', 'profiles', 'streak_grace_used_on',
  'profiles stores the UTC date on which grace was last consumed'
);
select has_function(
  'public', 'pulse_server_utc_date', ARRAY['timestamp with time zone'],
  'server UTC calendar-date helper exists'
);
select has_function(
  'public', 'calculate_streak_v1', ARRAY['date', 'integer', 'date', 'date'],
  'authoritative streak transition function exists'
);
select ok(
  to_regclass('public.activity_events_task_completion_idx') is not null,
  'task completion has a uniqueness guard against duplicate completion events'
);
select is_definer(
  'public', 'complete_task', ARRAY['uuid'],
  'task completion remains backend-authoritative through a security definer function'
);
select matches(
  pg_get_functiondef('public.complete_task(uuid)'::regprocedure),
  'for update',
  'task completion locks rows so concurrent retries serialize'
);

-- Server UTC is the only authoritative streak clock.
select is(
  public.pulse_server_utc_date('2026-09-09 23:59:59+00'),
  date '2026-09-09',
  'UTC date is Sep 9 immediately before UTC midnight'
);
select is(
  public.pulse_server_utc_date('2026-09-10 00:00:00+00'),
  date '2026-09-10',
  'UTC date changes exactly at server UTC midnight'
);

-- DST transitions are explicitly tested, but cannot change a UTC calendar date.
select is(
  public.pulse_server_utc_date('2026-03-08 23:30:00+00'),
  date '2026-03-08',
  'DST spring transition does not change UTC calendar-date semantics'
);
select is(
  public.pulse_server_utc_date('2026-11-01 23:30:00+00'),
  date '2026-11-01',
  'DST fall transition does not change UTC calendar-date semantics'
);

-- First qualifying activity.
select is(
  (public.calculate_streak_v1(null, 0, date '2026-09-10', null) ->> 'newStreak')::integer,
  1,
  'first qualifying activity starts a one-day streak'
);
select is(
  (public.calculate_streak_v1(null, 0, date '2026-09-10', null) ->> 'useGrace')::boolean,
  false,
  'first activity does not consume grace'
);

-- Same UTC calendar day is idempotent at the streak-transition level.
select is(
  (public.calculate_streak_v1(date '2026-09-10', 4, date '2026-09-10', null) ->> 'newStreak')::integer,
  4,
  'same calendar day does not inflate the streak'
);

-- Consecutive day increments normally.
select is(
  (public.calculate_streak_v1(date '2026-09-10', 4, date '2026-09-11', null) ->> 'newStreak')::integer,
  5,
  'consecutive UTC calendar day extends the streak by one'
);
select is(
  (public.calculate_streak_v1(date '2026-09-10', 4, date '2026-09-11', null) ->> 'useGrace')::boolean,
  false,
  'consecutive day does not consume grace'
);

-- Exactly one missed day: grace forgives it and extends by two.
select is(
  (public.calculate_streak_v1(date '2026-09-10', 4, date '2026-09-12', null) ->> 'newStreak')::integer,
  6,
  'exactly one missed calendar day is forgiven by grace'
);
select is(
  (public.calculate_streak_v1(date '2026-09-10', 4, date '2026-09-12', null) ->> 'useGrace')::boolean,
  true,
  'exactly one missed calendar day consumes grace'
);

-- Grace is unavailable inside the rolling seven-calendar-day window.
select is(
  (public.calculate_streak_v1(date '2026-09-15', 4, date '2026-09-17', date '2026-09-12') ->> 'newStreak')::integer,
  1,
  'recent grace use blocks another grace inside the rolling seven-day window'
);
select is(
  (public.calculate_streak_v1(date '2026-09-15', 4, date '2026-09-17', date '2026-09-12') ->> 'useGrace')::boolean,
  false,
  'blocked grace is not consumed'
);

-- Exactly seven calendar days after consumption, grace is available again.
select is(
  (public.calculate_streak_v1(date '2026-09-20', 8, date '2026-09-22', date '2026-09-15') ->> 'newStreak')::integer,
  10,
  'grace becomes available exactly seven calendar days after prior use'
);
select is(
  (public.calculate_streak_v1(date '2026-09-20', 8, date '2026-09-22', date '2026-09-15') ->> 'useGrace')::boolean,
  true,
  'grace is reusable when the rolling window has expired'
);

-- Two or more consecutive missed days reset the streak outright.
select is(
  (public.calculate_streak_v1(date '2026-09-10', 8, date '2026-09-13', null) ->> 'newStreak')::integer,
  1,
  'two or more missed calendar days reset the streak'
);
select is(
  (public.calculate_streak_v1(date '2026-09-10', 8, date '2026-09-13', null) ->> 'useGrace')::boolean,
  false,
  'two or more missed days cannot consume grace'
);

-- Grace is forgiveness only; the helper reports no synthetic activity mechanism.
select is(
  (public.calculate_streak_v1(date '2026-09-10', 4, date '2026-09-12', null) ->> 'gap')::integer,
  2,
  'grace transition is based on calendar-date gap'
);

-- The migration is prospective: an existing last activity date is used as-is;
-- no grace is consumed until a qualifying transition actually occurs.
select is(
  (public.calculate_streak_v1(date '2026-09-10', 4, date '2026-09-10', null) ->> 'useGrace')::boolean,
  false,
  'same-day migration-era state does not consume grace'
);

-- Concurrency contract: row lock + unique task-completion event guard are both present.
select ok(
  (length(pg_get_functiondef('public.complete_task(uuid)'::regprocedure)) -
   length(replace(pg_get_functiondef('public.complete_task(uuid)'::regprocedure), 'for update', ''))) > 0,
  'complete_task contains row-lock protection for retry races'
);
select matches(
  pg_get_indexdef('public.activity_events_task_completion_idx'::regclass),
  'unique',
  'task completion index is unique for defense in depth against concurrent duplicate events'
);

select * from finish();
rollback;
