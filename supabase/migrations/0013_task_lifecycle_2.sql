-- Slice 3A: task lifecycle 2.0 + additive recurring tasks.
-- Existing normal tasks remain first-class tasks. Recurrence is represented by
-- an optional task_series parent and deterministic occurrence_key on tasks.

create table public.task_series (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 500),
  description text,
  project_id uuid references public.projects(id) on delete set null,
  milestone_id uuid references public.milestones(id) on delete set null,
  priority integer not null default 0 check (priority between 0 and 3),
  recurrence_type text not null check (recurrence_type in ('daily', 'weekly', 'interval')),
  recurrence_interval integer not null default 1 check (recurrence_interval between 1 and 1000),
  timezone text not null default 'UTC' check (char_length(trim(timezone)) between 1 and 100),
  starts_at timestamptz not null,
  until_at timestamptz,
  occurrence_count integer check (occurrence_count is null or occurrence_count > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint task_series_until_after_start_chk check (until_at is null or until_at >= starts_at)
);

create index task_series_user_active_idx
  on public.task_series(user_id, is_active, starts_at, created_at);
create index task_series_project_idx
  on public.task_series(project_id, is_active, starts_at);

alter table public.tasks
  add column task_series_id uuid references public.task_series(id) on delete restrict,
  add column occurrence_key timestamptz,
  add column first_completed_at timestamptz;

create unique index tasks_series_occurrence_idx
  on public.tasks(task_series_id, occurrence_key)
  where task_series_id is not null and occurrence_key is not null;

create index tasks_series_idx
  on public.tasks(task_series_id, due_date, due_time);

-- Preserve historical completion timestamps without converting normal tasks
-- into series. Existing completed tasks remain ordinary tasks.
update public.tasks
set first_completed_at = completed_at
where completed_at is not null;

create or replace function public.validate_task_series_ownership()
returns trigger language plpgsql as $$
begin
  if new.task_series_id is not null then
    if not exists (
      select 1
      from public.task_series s
      where s.id = new.task_series_id
        and s.user_id = new.user_id
    ) then
      raise exception 'Task series does not belong to the task owner';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists tasks_validate_series_ownership on public.tasks;
create trigger tasks_validate_series_ownership
before insert or update of user_id, task_series_id on public.tasks
for each row execute function public.validate_task_series_ownership();

create or replace function public.validate_task_series_project_milestone()
returns trigger language plpgsql as $$
begin
  if new.milestone_id is not null then
    if new.project_id is null then
      raise exception 'A task series milestone must belong to a project';
    end if;
    if not exists (
      select 1
      from public.milestones m
      where m.id = new.milestone_id
        and m.project_id = new.project_id
        and m.user_id = new.user_id
    ) then
      raise exception 'Task series milestone does not belong to the series project';
    end if;
  end if;
  if new.project_id is not null then
    if not exists (
      select 1
      from public.projects p
      where p.id = new.project_id
        and p.user_id = new.user_id
    ) then
      raise exception 'Task series project does not belong to the series owner';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists task_series_validate_project_milestone on public.task_series;
create trigger task_series_validate_project_milestone
before insert or update of user_id, project_id, milestone_id on public.task_series
for each row execute function public.validate_task_series_project_milestone();

alter table public.task_series enable row level security;

create policy "users can read their task series" on public.task_series
  for select to authenticated
  using (user_id = auth.uid());
create policy "users can create their task series" on public.task_series
  for insert to authenticated
  with check (user_id = auth.uid());
create policy "users can update their task series" on public.task_series
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
create policy "users can delete their task series" on public.task_series
  for delete to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on public.task_series to authenticated;
grant all on public.task_series to service_role;

drop trigger if exists task_series_set_updated_at on public.task_series;
create trigger task_series_set_updated_at
before update on public.task_series
for each row execute function public.set_project_updated_at();

create or replace function public.reopen_task(p_task_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_task public.tasks%rowtype;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select * into v_task
  from public.tasks
  where id = p_task_id and user_id = v_uid
  for update;

  if not found then
    raise exception 'TASK_NOT_FOUND' using errcode = 'P0001';
  end if;
  if v_task.status = 'cancelled' then
    raise exception 'TASK_CANCELLED' using errcode = 'P0001';
  end if;
  if v_task.status <> 'completed' then
    return jsonb_build_object(
      'reopened', false,
      'alreadyOpen', true,
      'taskId', v_task.id,
      'status', v_task.status,
      'firstCompletedAt', v_task.first_completed_at
    );
  end if;

  update public.tasks
  set status = 'todo', completed_at = null, updated_at = now()
  where id = v_task.id
  returning * into v_task;

  return jsonb_build_object(
    'reopened', true,
    'alreadyOpen', false,
    'taskId', v_task.id,
    'status', v_task.status,
    'firstCompletedAt', v_task.first_completed_at
  );
end;
$$;

revoke all on function public.reopen_task(uuid) from public, anon;
grant execute on function public.reopen_task(uuid) to authenticated;
grant execute on function public.reopen_task(uuid) to service_role;

create or replace function public.ensure_task_occurrence(
  p_series_id uuid,
  p_occurrence_key timestamptz
)
returns public.tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_series public.task_series%rowtype;
  v_existing public.tasks%rowtype;
  v_local_start timestamp;
  v_local_occurrence timestamp;
  v_days integer;
  v_step_days integer;
  v_occurrence_number integer;
  v_due_date date;
  v_due_time time;
  v_inserted public.tasks%rowtype;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select * into v_series
  from public.task_series
  where id = p_series_id and user_id = v_uid
  for update;

  if not found then
    raise exception 'TASK_SERIES_NOT_FOUND' using errcode = 'P0001';
  end if;
  if not v_series.is_active then
    raise exception 'TASK_SERIES_INACTIVE' using errcode = 'P0001';
  end if;
  if p_occurrence_key < v_series.starts_at then
    raise exception 'OCCURRENCE_BEFORE_SERIES_START' using errcode = 'P0001';
  end if;
  if v_series.until_at is not null and p_occurrence_key > v_series.until_at then
    raise exception 'OCCURRENCE_AFTER_SERIES_END' using errcode = 'P0001';
  end if;

  v_local_start := v_series.starts_at at time zone v_series.timezone;
  v_local_occurrence := p_occurrence_key at time zone v_series.timezone;

  if v_local_occurrence::time <> v_local_start::time then
    raise exception 'OCCURRENCE_TIME_MISMATCH' using errcode = 'P0001';
  end if;

  v_days := v_local_occurrence::date - v_local_start::date;
  if v_series.recurrence_type = 'weekly' then
    if extract(isodow from v_local_occurrence::date) <> extract(isodow from v_local_start::date) then
      raise exception 'OCCURRENCE_WEEKDAY_MISMATCH' using errcode = 'P0001';
    end if;
    v_step_days := 7 * v_series.recurrence_interval;
  else
    v_step_days := v_series.recurrence_interval;
  end if;

  if v_days < 0 or mod(v_days, v_step_days) <> 0 then
    raise exception 'INVALID_OCCURRENCE_KEY' using errcode = 'P0001';
  end if;

  v_occurrence_number := (v_days / v_step_days) + 1;
  if v_series.occurrence_count is not null
     and v_occurrence_number > v_series.occurrence_count then
    raise exception 'OCCURRENCE_COUNT_EXCEEDED' using errcode = 'P0001';
  end if;

  select * into v_existing
  from public.tasks
  where task_series_id = v_series.id
    and occurrence_key = p_occurrence_key;

  if found then
    return v_existing;
  end if;

  v_due_date := v_local_occurrence::date;
  v_due_time := v_local_occurrence::time;

  insert into public.tasks(
    user_id, title, description, status, due_date, due_time,
    project_id, milestone_id, priority, task_series_id, occurrence_key
  )
  values(
    v_uid, v_series.title, v_series.description, 'todo', v_due_date, v_due_time,
    v_series.project_id, v_series.milestone_id, v_series.priority,
    v_series.id, p_occurrence_key
  )
  on conflict (task_series_id, occurrence_key) do nothing
  returning * into v_inserted;

  if found then
    return v_inserted;
  end if;

  select * into v_existing
  from public.tasks
  where task_series_id = v_series.id
    and occurrence_key = p_occurrence_key;
  return v_existing;
end;
$$;

revoke all on function public.ensure_task_occurrence(uuid, timestamptz) from public, anon;
grant execute on function public.ensure_task_occurrence(uuid, timestamptz) to authenticated;
grant execute on function public.ensure_task_occurrence(uuid, timestamptz) to service_role;

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
  v_existing_event_id uuid;
  v_xp_reward integer := 10;
  v_grace_used boolean := false;
  v_window_start date := v_today - 6;
  v_window_grace_count integer := 0;
  v_already_rewarded boolean := false;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select * into v_task
  from public.tasks
  where id = p_task_id and user_id = v_uid
  for update;
  if not found then
    raise exception 'TASK_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_task.status = 'cancelled' then
    raise exception 'TASK_CANCELLED' using errcode = 'P0001';
  end if;
  if v_task.status = 'completed' then
    return jsonb_build_object(
      'completed', false,
      'alreadyCompleted', true,
      'alreadyRewarded', true,
      'taskId', v_task.id,
      'xpAwarded', 0,
      'completedAt', v_task.completed_at,
      'firstCompletedAt', v_task.first_completed_at
    );
  end if;

  select id into v_existing_event_id
  from public.activity_events
  where user_id = v_uid
    and event_type = 'task_completed'
    and entity_id = v_task.id
  limit 1;

  v_already_rewarded := v_existing_event_id is not null or v_task.first_completed_at is not null;

  if v_already_rewarded then
    update public.tasks
    set status = 'completed', completed_at = now(), updated_at = now()
    where id = v_task.id
    returning * into v_task;

    return jsonb_build_object(
      'completed', true,
      'alreadyCompleted', false,
      'alreadyRewarded', true,
      'taskId', v_task.id,
      'eventId', v_existing_event_id,
      'xpAwarded', 0,
      'completedAt', v_task.completed_at,
      'firstCompletedAt', v_task.first_completed_at
    );
  end if;

  select * into v_profile
  from public.profiles
  where id = v_uid
  for update;
  if not found then
    raise exception 'PROFILE_NOT_FOUND' using errcode = 'P0001';
  end if;

  update public.tasks
  set status = 'completed', completed_at = now(),
      first_completed_at = coalesce(first_completed_at, now()), updated_at = now()
  where id = v_task.id
  returning * into v_task;

  insert into public.activity_events(user_id, event_type, entity_id, occurred_at, activity_date, metadata)
  values(v_uid, 'task_completed', v_task.id, now(), v_today, jsonb_build_object('source', 'task_completion'))
  returning id into v_event_id;

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

  update public.profiles
  set total_activities = v_total_activities,
      current_streak = v_new_streak,
      longest_streak = v_longest_streak,
      xp = v_new_xp,
      level = v_new_level,
      last_activity_date = v_today
  where id = v_uid;

  return jsonb_build_object(
    'completed', true,
    'alreadyCompleted', false,
    'alreadyRewarded', false,
    'taskId', v_task.id,
    'eventId', v_event_id,
    'xpAwarded', v_xp_reward,
    'newXP', v_new_xp,
    'newLevel', v_new_level,
    'newStreak', v_new_streak,
    'longestStreak', v_longest_streak,
    'totalActivities', v_total_activities,
    'graceUsed', v_grace_used,
    'completedAt', v_task.completed_at,
    'firstCompletedAt', v_task.first_completed_at
  );
end;
$$;

revoke all on function public.complete_task(uuid) from public, anon;
grant execute on function public.complete_task(uuid) to authenticated;
grant execute on function public.complete_task(uuid) to service_role;

comment on table public.task_series is 'Recurring task scheduling definitions. Each generated occurrence remains an ordinary public.tasks row.';
comment on column public.tasks.task_series_id is 'Optional recurrence parent. Null means this is a normal non-recurring task.';
comment on column public.tasks.occurrence_key is 'Deterministic recurrence occurrence timestamp in the series schedule timezone.';
comment on column public.tasks.first_completed_at is 'Immutable first completion timestamp used to preserve reward identity across reopen/recomplete.';
comment on function public.complete_task(uuid) is 'Lifecycle 2.0: completion reward is consumed once per task identity, even after reopen; recurring occurrences use distinct task identities.';
comment on function public.reopen_task(uuid) is 'Lifecycle 2.0: reopens a task without reversing rewards or deleting completion history.';
comment on function public.ensure_task_occurrence(uuid, timestamptz) is 'Lifecycle 2.0: validates and idempotently creates one recurring task occurrence.';
