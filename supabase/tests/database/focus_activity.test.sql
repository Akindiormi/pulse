begin;

create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  (gen_random_uuid(), 'authenticated', 'authenticated', 'focus-activity-owner@example.com', '', now(), '{}', '{}', now(), now());

create temporary table focus_activity_user(id uuid not null);
insert into focus_activity_user select id from auth.users where email = 'focus-activity-owner@example.com';
grant select on focus_activity_user to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', (select id::text from focus_activity_user), true);

insert into public.focus_sessions(user_id, planned_duration_seconds)
select id, 1200 from focus_activity_user;

select is((select count(*) from public.activity_events where user_id = (select id from focus_activity_user) and event_type = 'focus_completed'), 0::bigint, 'running Focus session has no completion activity');

update public.focus_sessions set status = 'completed' where user_id = (select id from focus_activity_user);

select is((select count(*) from public.activity_events where user_id = (select id from focus_activity_user) and event_type = 'focus_completed'), 1::bigint, 'completed Focus session emits focus_completed');
select is((select activity_date from public.activity_events where user_id = (select id from focus_activity_user) and event_type = 'focus_completed'), timezone('utc', clock_timestamp())::date, 'focus completion uses server UTC activity date');
select is((select current_streak from public.profiles where id = (select id from focus_activity_user)), 1, 'focus completion qualifies for streak');
select is((select total_activities from public.profiles where id = (select id from focus_activity_user)), 1, 'focus completion counts as one activity');
select is((select count(*) from public.activity_events where user_id = (select id from focus_activity_user) and event_type = 'task_completed'), 0::bigint, 'focus completion does not emit task_completed');

insert into public.focus_sessions(user_id, planned_duration_seconds)
select id, 1200 from focus_activity_user;
update public.focus_sessions set status = 'cancelled' where user_id = (select id from focus_activity_user) and status = 'running';
select is((select count(*) from public.activity_events where user_id = (select id from focus_activity_user) and event_type = 'focus_completed'), 1::bigint, 'cancelled Focus session emits no focus_completed');

rollback;
