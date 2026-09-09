-- Slice 1B: streak hardening.
--
-- Day definition:
--   A Pulse day is the calendar date in the user's IANA timezone stored on profiles.timezone.
--   The timezone is initialized from the device and may be updated when the device timezone changes.
--   If no timezone is available, UTC is used as the deterministic fallback.
--   Streaks compare calendar dates, never elapsed hours, so DST 23/25-hour days do not change semantics.
--
-- Grace definition:
--   One grace day may cover exactly one missed calendar day.
--   Grace availability is a rolling 7-calendar-day window: if grace was used on date D,
--   another grace cannot be used until D + 7. Grace never creates an activity event.
--   A gap of more than one missed calendar day cannot be repaired by one grace day.
--
-- Migration v1 remains prospective: existing streak state is preserved and the migration itself
-- does not create activity, reset a streak, or consume grace.

alter table public.profiles
  add column if not exists streak_grace_used_on date;

comment on column public.profiles.timezone is
  'IANA timezone used to define the user calendar day. Initialized from device and updated when the device timezone changes; UTC is the fallback.';

comment on column public.profiles.streak_grace_used_on is
  'Calendar date on which the most recent rolling-7-day streak grace was consumed.';

create or replace function public.pulse_local_date(
  p_at timestamptz,
  p_timezone text
)
returns date
language sql
immutable
as $$
  select (p_at at time zone coalesce(nullif(trim(p_timezone), ''), 'UTC'))::date;
$$;

create or replace function public.calculate_streak_v1(
  p_last_activity_date date,
  p_current_streak integer,
  p_today date,
  p_grace_used_on date
)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_gap integer;
  v_new_streak integer;
  v_use_grace boolean := false;
begin
  if p_last_activity_date is null then
    v_new_streak := 1;
  elsif p_last_activity_date = p_today then
    v_new_streak := greatest(p_current_streak, 1);
  else
    v_gap := p_today - p_last_activity_date;

    if v_gap = 1 then
      v_new_streak := greatest(p_current_streak, 0) + 1;
    elsif v_gap = 2
      and p_current_streak > 0
      and (p_grace_used_on is null or p_today - p_grace_used_on >= 7)
    then
      v_use_grace := true;
      v_new_streak := p_current_streak + 2;
    else
      v_new_streak := 1;
    end if;
  end if;

  return jsonb_build_object(
    'newStreak', v_new_streak,
    'useGrace', v_use_grace,
    'gap', coalesce(v_gap, 0)
  );
end;
$$;

comment on function public.calculate_streak_v1(date, integer, date, date) is
  'Authoritative Slice 1B streak transition: calendar-date comparison plus one grace day per rolling 7 calendar days.';

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
  v_today date;
  v_transition jsonb;
  v_new_streak integer;
  v_longest_streak integer;
  v_total_activities integer;
  v_new_xp bigint;
  v_new_level integer;
  v_event_id uuid;
  v_xp_reward integer := 10;
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

  if v_task.status = 'completed' then
    return jsonb_build_object(
      'completed', false,
      'alreadyCompleted', true,
      'taskId', v_task.id,
      'xpAwarded', 0
    );
  end if;

  if v_task.status = 'cancelled' then
    raise exception 'TASK_CANCELLED' using errcode = 'P0001';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_uid
  for update;

  if not found then
    raise exception 'PROFILE_NOT_FOUND' using errcode = 'P0001';
  end if;

  -- The server defines the calendar day from the user's IANA timezone.
  -- Historical streak state is not recalculated during migration; it is simply used as-is.
  v_today := public.pulse_local_date(now(), v_profile.timezone);

  update public.tasks
  set status = 'completed', completed_at = now(), updated_at = now()
  where id = v_task.id
  returning * into v_task;

  insert into public.activity_events(
    user_id, event_type, entity_id, occurred_at, activity_date, metadata
  )
  values(
    v_uid,
    'task_completed',
    v_task.id,
    now(),
    v_today,
    jsonb_build_object('source', 'task_completion')
  )
  returning id into v_event_id;

  v_transition := public.calculate_streak_v1(
    v_profile.last_activity_date,
    v_profile.current_streak,
    v_today,
    v_profile.streak_grace_used_on
  );
  v_new_streak := (v_transition ->> 'newStreak')::integer;

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
      last_activity_date = v_today,
      streak_grace_used_on = case
        when (v_transition ->> 'useGrace')::boolean then v_today
        else streak_grace_used_on
      end
  where id = v_uid;

  return jsonb_build_object(
    'completed', true,
    'alreadyCompleted', false,
    'taskId', v_task.id,
    'eventId', v_event_id,
    'xpAwarded', v_xp_reward,
    'newXP', v_new_xp,
    'newLevel', v_new_level,
    'newStreak', v_new_streak,
    'longestStreak', v_longest_streak,
    'totalActivities', v_total_activities,
    'activityDate', v_today,
    'graceUsed', (v_transition ->> 'useGrace')::boolean,
    'completedAt', v_task.completed_at
  );
end;
$$;

revoke all on function public.pulse_local_date(timestamptz, text) from public, anon;
grant execute on function public.pulse_local_date(timestamptz, text) to authenticated, service_role;

revoke all on function public.calculate_streak_v1(date, integer, date, date) from public, anon;
grant execute on function public.calculate_streak_v1(date, integer, date, date) to authenticated, service_role;

revoke all on function public.complete_task(uuid) from public, anon;
grant execute on function public.complete_task(uuid) to authenticated, service_role;
