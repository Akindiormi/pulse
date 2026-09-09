begin;

create extension if not exists pgtap with schema extensions;
select plan(37);

create temporary table focus_test_users (name text primary key, id uuid not null);
grant select on focus_test_users to authenticated;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  (gen_random_uuid(), 'authenticated', 'authenticated', 'focus-persist-owner@example.com', '', now(), '{}', '{}', now(), now()),
  (gen_random_uuid(), 'authenticated', 'authenticated', 'focus-persist-other@example.com', '', now(), '{}', '{}', now(), now());

insert into focus_test_users(name, id)
select case when email = 'focus-persist-owner@example.com' then 'owner' else 'other' end, id
from auth.users
where email in ('focus-persist-owner@example.com', 'focus-persist-other@example.com');

insert into public.tasks(user_id, title)
select id, 'Persistence task' from focus_test_users where name = 'owner';
insert into public.tasks(user_id, title)
select id, 'Other task' from focus_test_users where name = 'other';

create temporary table focus_test_tasks (owner_task_id uuid not null, other_task_id uuid not null);
grant select on focus_test_tasks to authenticated;
insert into focus_test_tasks(owner_task_id, other_task_id)
select
  (select id from public.tasks where title = 'Persistence task'),
  (select id from public.tasks where title = 'Other task');

set local role authenticated;
select set_config('request.jwt.claim.sub', (select id::text from focus_test_users where name = 'owner'), true);

insert into public.focus_sessions(user_id, planned_duration_seconds)
select id, 1800 from focus_test_users where name = 'owner';

select is((select count(*) from public.focus_sessions where user_id = (select id from focus_test_users where name = 'owner')), 1::bigint, 'standalone session is created');
select is((select status from public.focus_sessions where user_id = (select id from focus_test_users where name = 'owner')), 'running', 'new session starts running');
select is((select active_duration_seconds from public.focus_sessions where user_id = (select id from focus_test_users where name = 'owner')), 0, 'new session starts with zero active duration');
select ok((select started_at is not null and created_at is not null and updated_at is not null from public.focus_sessions where user_id = (select id from focus_test_users where name = 'owner')), 'creation timestamps are populated');

select throws_ok(
  $$insert into public.focus_sessions(user_id, planned_duration_seconds) values ((select id from focus_test_users where name = 'owner'), 1800)$$,
  'duplicate key value violates unique constraint "focus_sessions_one_active_per_user_idx"',
  'second active session is rejected by the database'
);

select set_config('request.jwt.claim.sub', (select id::text from focus_test_users where name = 'other'), true);
select throws_ok(
  $$insert into public.focus_sessions(user_id, task_id, planned_duration_seconds) values ((select id from focus_test_users where name = 'other'), (select owner_task_id from focus_test_tasks), 1800)$$,
  'Focus task does not belong to the session owner',
  'cross-owner task association is rejected'
);

select set_config('request.jwt.claim.sub', (select id::text from focus_test_users where name = 'owner'), true);
select pg_sleep(2);
update public.focus_sessions set status = 'paused' where task_id is null;
select is((select status from public.focus_sessions where task_id is null), 'paused', 'running session can pause');
select ok((select active_duration_seconds >= 1 from public.focus_sessions where task_id is null), 'pause persists server-calculated active duration');
select ok((select ended_at is null from public.focus_sessions where task_id is null), 'paused session has no ended_at');

select throws_ok(
  $$update public.focus_sessions set status = 'paused' where task_id is null$$,
  'Focus session is already paused',
  'repeated pause is rejected'
);

update public.focus_sessions set status = 'running' where task_id is null;
select is((select status from public.focus_sessions where task_id is null), 'running', 'paused session resumes');
select ok((select active_duration_seconds >= 1 from public.focus_sessions where task_id is null), 'resume preserves accumulated duration');

select throws_ok(
  $$update public.focus_sessions set status = 'running' where task_id is null$$,
  'Focus session is already running',
  'repeated resume is rejected'
);

select pg_sleep(2);
update public.focus_sessions set status = 'completed' where task_id is null;
select is((select status from public.focus_sessions where task_id is null), 'completed', 'running session completes');
select ok((select active_duration_seconds >= 2 from public.focus_sessions where task_id is null), 'completion persists final accumulated active duration');
select ok((select ended_at is not null from public.focus_sessions where task_id is null), 'completion gets a server timestamp');
select is((select count(*) from public.focus_sessions where task_id is null), 1::bigint, 'completed session remains persisted');

select throws_ok($$update public.focus_sessions set status = 'running' where task_id is null$$, 'Terminal focus sessions cannot change lifecycle state', 'completed cannot resume');
select throws_ok($$update public.focus_sessions set status = 'paused' where task_id is null$$, 'Terminal focus sessions cannot change lifecycle state', 'completed cannot pause');
select throws_ok($$update public.focus_sessions set status = 'cancelled' where task_id is null$$, 'Terminal focus sessions cannot change lifecycle state', 'completed cannot cancel');

insert into public.focus_sessions(user_id, task_id, planned_duration_seconds)
select (select id from focus_test_users where name = 'owner'), owner_task_id, 1200 from focus_test_tasks;
select is((select count(*) from public.focus_sessions where task_id = (select owner_task_id from focus_test_tasks)), 1::bigint, 'task-linked session is created');
select is((select active_duration_seconds from public.focus_sessions where task_id = (select owner_task_id from focus_test_tasks)), 0, 'task-linked session starts at zero');

select pg_sleep(2);
update public.focus_sessions set status = 'paused' where task_id = (select owner_task_id from focus_test_tasks);
select is((select status from public.focus_sessions where task_id = (select owner_task_id from focus_test_tasks)), 'paused', 'task-linked session can pause');
select ok((select active_duration_seconds >= 1 from public.focus_sessions where task_id = (select owner_task_id from focus_test_tasks)), 'task-linked pause preserves active duration');

update public.focus_sessions set status = 'cancelled' where task_id = (select owner_task_id from focus_test_tasks);
select is((select status from public.focus_sessions where task_id = (select owner_task_id from focus_test_tasks)), 'cancelled', 'paused session can cancel');
select ok((select ended_at is not null from public.focus_sessions where task_id = (select owner_task_id from focus_test_tasks)), 'cancel persists ended_at');
select is((select count(*) from public.focus_sessions where status = 'cancelled'), 1::bigint, 'cancelled session remains historical');

select throws_ok($$update public.focus_sessions set status = 'running' where status = 'cancelled'$$, 'Terminal focus sessions cannot change lifecycle state', 'cancelled cannot resume');

insert into public.focus_sessions(user_id, planned_duration_seconds)
select id, 1200 from focus_test_users where name = 'owner';
select pg_sleep(2);
update public.focus_sessions set status = 'paused' where status = 'running' and task_id is null;
select is((select count(*) from public.focus_sessions where user_id = (select id from focus_test_users where name = 'owner') and status in ('running','paused')), 1::bigint, 'exactly one active session is visible');
select is((select count(*) from public.focus_sessions where user_id = (select id from focus_test_users where name = 'owner') and status = 'completed'), 1::bigint, 'completed session is not active');
select is((select count(*) from public.focus_sessions where user_id = (select id from focus_test_users where name = 'owner') and status = 'cancelled'), 1::bigint, 'cancelled session is not active');

select set_config('request.jwt.claim.sub', (select id::text from focus_test_users where name = 'other'), true);
select is((select count(*) from public.focus_sessions), 0::bigint, 'other user cannot read owner Focus sessions');
update public.focus_sessions set status = 'completed';
select is((select count(*) from public.focus_sessions), 0::bigint, 'other user cannot mutate owner Focus sessions');

select set_config('request.jwt.claim.sub', (select id::text from focus_test_users where name = 'owner'), true);
select is((select count(*) from public.focus_sessions), 3::bigint, 'owner history returns all persisted sessions');
select ok((select count(*) = 3 from (select started_at, lead(started_at) over (order by started_at desc) as next_started_at from public.focus_sessions) ordered where next_started_at is null or started_at >= next_started_at), 'history timestamps have predictable descending order');

delete from public.tasks where id = (select owner_task_id from focus_test_tasks);
select is((select count(*) from public.focus_sessions where task_id is null), 3::bigint, 'task deletion preserves Focus rows and clears task association');
select is((select count(*) from public.focus_sessions), 3::bigint, 'task deletion does not delete Focus history');

select * from finish();
rollback;
