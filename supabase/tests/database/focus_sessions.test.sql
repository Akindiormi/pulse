begin;

create extension if not exists pgtap with schema extensions;

select plan(37);

select has_table(
  'public', 'focus_sessions',
  'focus_sessions table exists'
);
select has_column('public', 'focus_sessions', 'user_id', 'focus session has owner');
select has_column('public', 'focus_sessions', 'task_id', 'focus session can associate a task');
select has_column('public', 'focus_sessions', 'status', 'focus session has lifecycle status');
select has_column('public', 'focus_sessions', 'planned_duration_seconds', 'focus session stores planned duration');
select has_column('public', 'focus_sessions', 'started_at', 'focus session stores start timestamp');
select has_column('public', 'focus_sessions', 'ended_at', 'focus session stores optional end timestamp');
select has_column('public', 'focus_sessions', 'active_duration_seconds', 'focus session stores authoritative active duration');

select col_not_null('public', 'focus_sessions', 'user_id', 'focus session owner is required');
select col_not_null('public', 'focus_sessions', 'status', 'focus session status is required');
select col_not_null('public', 'focus_sessions', 'planned_duration_seconds', 'planned duration is required');
select col_not_null('public', 'focus_sessions', 'started_at', 'start timestamp is required');
select col_not_null('public', 'focus_sessions', 'active_duration_seconds', 'active duration is required');
select col_has_default('public', 'focus_sessions', 'status', 'focus sessions default to running');
select col_has_default('public', 'focus_sessions', 'active_duration_seconds', 'focus sessions default active duration to zero');

select fk_ok('public', 'focus_sessions', 'user_id', 'public', 'profiles', 'id', 'focus session belongs to a profile');
select fk_ok('public', 'focus_sessions', 'task_id', 'public', 'tasks', 'id', 'focus session task association points to tasks');

select has_index('public', 'focus_sessions', 'focus_sessions_user_started_idx', 'focus sessions have a user history index');
select has_index('public', 'focus_sessions', 'focus_sessions_user_status_idx', 'focus sessions have a user status index');
select has_index('public', 'focus_sessions', 'focus_sessions_task_idx', 'focus sessions have a task history index');

select policies_are('public', 'focus_sessions', ARRAY[
  'users can read their focus sessions',
  'users can create their focus sessions',
  'users can update their focus sessions',
  'users can delete their focus sessions'
], 'focus session RLS policies exist');

select has_function(
  'public', 'validate_focus_session_transition', ARRAY[]::text[],
  'focus lifecycle validation trigger function exists'
);

select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    where n.nspname = 'public'
      and r.relname = 'focus_sessions'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) like '%active_duration_seconds >= 0%'
  ),
  'database enforces non-negative active duration'
);

select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    where n.nspname = 'public'
      and r.relname = 'focus_sessions'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) like '%planned_duration_seconds > 0%'
  ),
  'database requires a positive planned duration'
);

select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    where n.nspname = 'public'
      and r.relname = 'focus_sessions'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) like '%status in (''running'', ''paused'')%'
  ),
  'database requires active sessions to have no ended_at timestamp'
);

select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    where n.nspname = 'public'
      and r.relname = 'focus_sessions'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) like '%status in (''completed'', ''cancelled'')%'
  ),
  'database requires terminal sessions to have ended_at'
);

select is(
  (
    select c.confdeltype
    from pg_constraint c
    join pg_class child on child.oid = c.conrelid
    join pg_class parent on parent.oid = c.confrelid
    where child.relname = 'focus_sessions'
      and parent.relname = 'tasks'
      and c.contype = 'f'
    limit 1
  ),
  'n',
  'deleting a task sets focus task_id to null rather than deleting the session'
);

-- Create isolated test identities as the database owner, then exercise the
-- actual authenticated role and auth.uid()-based RLS policies below.
create temporary table focus_test_users (
  name text primary key,
  id uuid not null
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (gen_random_uuid(), 'authenticated', 'authenticated', 'focus-test-owner@example.com', '', now(), '{}', '{}', now(), now()),
  (gen_random_uuid(), 'authenticated', 'authenticated', 'focus-test-other@example.com', '', now(), '{}', '{}', now(), now());

insert into focus_test_users(name, id)
select 'owner', id from auth.users where email = 'focus-test-owner@example.com';
insert into focus_test_users(name, id)
select 'other', id from auth.users where email = 'focus-test-other@example.com';

insert into public.tasks (user_id, title)
select id, 'Focus foundation test task' from focus_test_users where name = 'owner';
insert into public.tasks (user_id, title)
select id, 'Other owner task' from focus_test_users where name = 'other';

create temporary table focus_test_rows (
  session_id uuid not null,
  task_id uuid not null
);

insert into focus_test_rows(session_id, task_id)
select null::uuid, id from public.tasks where title = 'Focus foundation test task' limit 1;

-- Exercise the actual authenticated role and auth.uid()-based RLS policies.
set local role authenticated;
select set_config('request.jwt.claim.sub', (select id::text from focus_test_users where name = 'owner'), true);

insert into public.focus_sessions (
  task_id,
  status,
  planned_duration_seconds,
  started_at,
  active_duration_seconds
)
select id, 'running', 1800, now() - interval '1500 seconds', 0
from public.tasks
where title = 'Focus foundation test task';

update focus_test_rows
set session_id = (
  select id from public.focus_sessions
  where task_id = focus_test_rows.task_id
  order by created_at desc
  limit 1
);

select is(
  (select count(*) from public.focus_sessions where user_id = (select id from focus_test_users where name = 'owner')),
  1::bigint,
  'owner can create a focus session'
);

select throws_ok(
  $$insert into public.focus_sessions (task_id, planned_duration_seconds, started_at) select id, 1800, now() from public.tasks where title = 'Other owner task'$$,
  'Focus task does not belong to the session owner',
  'database rejects cross-owner task associations'
);

update public.focus_sessions
set status = 'paused', active_duration_seconds = 1500
where id = (select session_id from focus_test_rows);

select is(
  (select status from public.focus_sessions where id = (select session_id from focus_test_rows)),
  'paused',
  'running session can transition to paused'
);

update public.focus_sessions
set status = 'running'
where id = (select session_id from focus_test_rows);

select is(
  (select status from public.focus_sessions where id = (select session_id from focus_test_rows)),
  'running',
  'paused session can resume to running'
);

select throws_ok(
  $$update public.focus_sessions set active_duration_seconds = -1 where id = (select session_id from focus_test_rows)$$,
  'Active duration cannot be negative',
  'negative active duration is rejected'
);

select throws_ok(
  $$update public.focus_sessions set status = 'completed', ended_at = started_at - interval '1 second' where id = (select session_id from focus_test_rows)$$,
  'ended_at cannot be before started_at',
  'ended_at before started_at is rejected'
);

update public.focus_sessions
set status = 'completed',
    ended_at = now(),
    active_duration_seconds = 1500
where id = (select session_id from focus_test_rows);

select is(
  (select status from public.focus_sessions where id = (select session_id from focus_test_rows)),
  'completed',
  'running session can complete with persisted active duration'
);

select throws_ok(
  $$update public.focus_sessions set status = 'running' where id = (select session_id from focus_test_rows)$$,
  'Terminal focus sessions cannot change lifecycle state',
  'completed sessions cannot resume'
);

-- Switch identity: the second authenticated user must not see or mutate the
-- owner's session through the owner-scoped RLS policies.
select set_config('request.jwt.claim.sub', (select id::text from focus_test_users where name = 'other'), true);

select is(
  (select count(*) from public.focus_sessions where id = (select session_id from focus_test_rows)),
  0::bigint,
  'another authenticated user cannot read the owner session'
);

update public.focus_sessions
set active_duration_seconds = 1499
where id = (select session_id from focus_test_rows);

select is(
  (select active_duration_seconds from public.focus_sessions where id = (select session_id from focus_test_rows)),
  null::integer,
  'another authenticated user cannot mutate the owner session'
);

-- Return to the owner for the historical task-deletion contract.
select set_config('request.jwt.claim.sub', (select id::text from focus_test_users where name = 'owner'), true);

delete from public.tasks
where id = (select task_id from focus_test_rows);

select is(
  (select task_id from public.focus_sessions where id = (select session_id from focus_test_rows)),
  null::uuid,
  'deleting a task clears task_id but preserves the Focus session'
);

select is(
  (select status from public.focus_sessions where id = (select session_id from focus_test_rows)),
  'completed',
  'historical Focus session remains after task deletion'
);

select * from finish();
rollback;
