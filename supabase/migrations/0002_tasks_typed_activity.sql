-- Slice 1A: real-life tasks + typed activity events.
-- Deliberately separate from the legacy challenge-shaped `activities` table.
-- This keeps challenge history stable while the new activity model grows independently.
--
-- Slice 1B streak contract:
-- 1. A Pulse streak day is a SERVER UTC calendar date. The device timezone is never authoritative.
-- 2. Streak continuity is based on calendar dates, never elapsed hours. This therefore remains correct across DST transitions.
-- 3. Historical streak state is preserved exactly at migration. Migration itself creates no activity and does not touch the streak clock.
-- 4. Grace semantics: one missed qualifying day may be forgiven per rolling 7-day window. A grace day is consumed only when a qualifying activity occurs after exactly one missed day; it does not create activity, XP, or change the stored activity date. Two or more consecutive missed days break the streak.
-- 5. The rolling window is evaluated against server UTC calendar dates, inclusive of the qualifying activity date and the six preceding UTC dates. It is not a fixed Monday-Sunday week and never resets at a fixed weekday.
-- 6. Repeated completion of the same task is idempotent. The unique task-completion event plus row lock prevents duplicate rewards/events, including concurrent retries.

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 500),
  description text,
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'completed', 'cancelled')),
  due_date date,
  due_time time,
  project_id uuid,
  milestone_id uuid,
  priority integer not null default 0 check (priority between 0 and 3),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tasks_user_status_due_idx on public.tasks(user_id, status, due_date, due_time);
create index tasks_user_updated_idx on public.tasks(user_id, updated_at desc);

create table public.activity_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check (event_type in ('task_completed', 'focus_completed', 'milestone_completed', 'project_completed')),
  entity_id uuid,
  occurred_at timestamptz not null default now(),
  activity_date date not null default (timezone('utc', now())::date),
  metadata jsonb not null default '{}'::jsonb
);

create index activity_events_user_date_idx on public.activity_events(user_id, activity_date desc, occurred_at desc);
create unique index activity_events_task_completion_idx on public.activity_events(user_id, event_type, entity_id) where event_type = 'task_completed' and entity_id is not null;

alter table public.tasks enable row level security;
alter table public.activity_events enable row level security;

create policy "users can read their tasks" on public.tasks for select to authenticated using (user_id = auth.uid());
create policy "users can create their tasks" on public.tasks for insert to authenticated with check (user_id = auth.uid());
create policy "users can update their tasks" on public.tasks for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "users can delete their tasks" on public.tasks for delete to authenticated using (user_id = auth.uid());
create policy "users can read their activity events" on public.activity_events for select to authenticated using (user_id = auth.uid());

revoke all on public.tasks, public.activity_events from anon;
grant select, insert, update, delete on public.tasks to authenticated;
grant select on public.activity_events to authenticated;
grant all on public.tasks, public.activity_events to service_role;

create or replace function public.set_task_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tasks_set_updated_at on public.tasks;
create trigger tasks_set_updated_at before update on public.tasks for each row execute function public.set_task_updated_at();

-- Backend-authoritative task completion. The migration itself creates no activity event.
create or replace function public.complete_task(p_task_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_task public.tasks%rowtype;
  v_profile public.profiles%rowtype;
  v_today date := timezone('utc', now())::date;
  v_new_streak integer;
  v_longest_streak integer;
  v_total_activities integer;
  v_new_xp bigint;
  v_new_level integer;
  v_event_id uuid;
  v_xp_reward integer := 10;
  v_grace_used boolean := false;
  v_window_start date := v_today - 6;
  v_window_grace_count integer := 0;
begin
  if v_uid is null then raise exception 'UNAUTHENTICATED' using errcode = 'P0001'; end if;

  select * into v_task from public.tasks where id = p_task_id and user_id = v_uid for update;
  if not found then raise exception 'TASK_NOT_FOUND' using errcode = 'P0001'; end if;

  if v_task.status = 'completed' then
    return jsonb_build_object('completed', false, 'alreadyCompleted', true, 'taskId', v_task.id, 'xpAwarded', 0);
  end if;
  if v_task.status = 'cancelled' then raise exception 'TASK_CANCELLED' using errcode = 'P0001'; end if;

  select * into v_profile from public.profiles where id = v_uid for update;
  if not found then raise exception 'PROFILE_NOT_FOUND' using errcode = 'P0001'; end if;

  update public.tasks set status = 'completed', completed_at = now(), updated_at = now() where id = v_task.id returning * into v_task;

  insert into public.activity_events(user_id, event_type, entity_id, occurred_at, activity_date, metadata)
  values(v_uid, 'task_completed', v_task.id, now(), v_today, jsonb_build_object('source', 'task_completion'))
  returning id into v_event_id;

  -- Count already-used grace days from the rolling UTC 7-day calendar window.
  -- A grace day is represented by exactly one missing calendar date between
  -- qualifying activity dates; the current completion can consume at most one.
  -- Consecutive-day activity remains the normal path and consumes none.
  if v_profile.last_activity_date is null then
    v_new_streak := 1;
  elsif v_profile.last_activity_date = v_today then
    v_new_streak := greatest(v_profile.current_streak, 1);
  elsif v_profile.last_activity_date = v_today - 1 then
    v_new_streak := v_profile.current_streak + 1;
  else
    select count(distinct activity_date) into v_window_grace_count
    from public.activity_events
    where user_id = v_uid
      and activity_date >= v_window_start
      and activity_date < v_today
      and activity_date > v_profile.last_activity_date;

    -- The only eligible gap is exactly one missed UTC calendar day since the
    -- last qualifying activity. Grace is consumed once for that gap; larger
    -- gaps reset the streak.
    if v_profile.last_activity_date = v_today - 2 and v_window_grace_count >= 1 then
      v_new_streak := v_profile.current_streak + 1;
      v_grace_used := true;
    else
      v_new_streak := 1;
    end if;
  end if;

  v_longest_streak := greatest(v_profile.longest_streak, v_new_streak);
  v_total_activities := v_profile.total_activities + 1;
  v_new_xp := v_profile.xp + v_xp_reward;
  v_new_level := public.level_for_xp(v_new_xp);

  update public.profiles set total_activities = v_total_activities, current_streak = v_new_streak, longest_streak = v_longest_streak, xp = v_new_xp, level = v_new_level, last_activity_date = v_today where id = v_uid;

  return jsonb_build_object('completed', true, 'alreadyCompleted', false, 'taskId', v_task.id, 'eventId', v_event_id, 'xpAwarded', v_xp_reward, 'newXP', v_new_xp, 'newLevel', v_new_level, 'newStreak', v_new_streak, 'longestStreak', v_longest_streak, 'totalActivities', v_total_activities, 'graceUsed', v_grace_used, 'completedAt', v_task.completed_at);
end;
$$;

revoke all on function public.complete_task(uuid) from public, anon;
grant execute on function public.complete_task(uuid) to authenticated;
grant execute on function public.complete_task(uuid) to service_role;

comment on table public.activity_events is 'Typed meaningful activity events. Allowed event types are intentionally explicit; do not replace with a generic arbitrary activity string.';
comment on column public.tasks.project_id is 'Reserved for the Phase 1 Projects slice; no FK is added until the projects table exists.';
comment on column public.tasks.milestone_id is 'Reserved for the Phase 1 Projects slice; no FK is added until the milestones table exists.';
comment on function public.complete_task(uuid) is 'Slice 1B streak contract: server UTC calendar days, calendar-date comparison across DST, one grace-eligible missed day, and idempotent task completion.';
