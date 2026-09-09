-- Slice 4 Phase 3: finalize Focus transition validation ordering.
-- Keep lifecycle transitions authoritative while allowing task deletion to clear
-- task_id on terminal history rows.

create or replace function public.validate_focus_session_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_elapsed_seconds integer;
  v_task_user_id uuid;
begin
  if new.task_id is not null then
    select user_id into v_task_user_id from public.tasks where id = new.task_id;
    if v_task_user_id is null then raise exception 'Focus task does not exist'; end if;
    if v_task_user_id <> new.user_id then raise exception 'Focus task does not belong to the session owner'; end if;
  end if;

  if new.active_duration_seconds < 0 then
    raise exception 'Active duration cannot be negative';
  end if;
  if new.ended_at is not null and new.ended_at < new.started_at then
    raise exception 'ended_at cannot be before started_at';
  end if;

  if tg_op = 'UPDATE' then
    if new.user_id <> old.user_id then raise exception 'Focus session owner cannot change'; end if;

    if old.status in ('completed', 'cancelled') then
      if new.status <> old.status then
        raise exception 'Terminal focus sessions cannot change lifecycle state';
      end if;
      if new.active_duration_seconds <> old.active_duration_seconds then
        raise exception 'Terminal focus sessions are immutable';
      end if;
      -- task_id may be cleared by ON DELETE SET NULL to preserve history.
    elsif old.status = 'running' then
      if new.status = 'running' then raise exception 'Focus session is already running'; end if;
      if new.status not in ('paused', 'completed', 'cancelled') then
        raise exception 'Invalid focus session transition';
      end if;
      -- now() is transaction-scoped in PostgreSQL. Focus duration must use the
      -- wall clock so pg_sleep/background time is reflected in persisted time.
      v_elapsed_seconds := greatest(extract(epoch from (clock_timestamp() - old.updated_at))::integer, 0);
      new.active_duration_seconds := old.active_duration_seconds + v_elapsed_seconds;
    elsif old.status = 'paused' then
      if new.status = 'paused' then raise exception 'Focus session is already paused'; end if;
      if new.status not in ('running', 'completed', 'cancelled') then
        raise exception 'Invalid focus session transition';
      end if;
      if new.active_duration_seconds < old.active_duration_seconds then
        raise exception 'Active duration cannot decrease';
      end if;
    end if;

    if new.status in ('completed', 'cancelled') then
      new.ended_at = clock_timestamp();
    elsif new.status in ('running', 'paused') then
      new.ended_at = null;
    end if;
  end if;

  if new.status in ('running', 'paused') and new.ended_at is not null then
    raise exception 'Active focus sessions cannot have an ended_at timestamp';
  end if;
  if new.status in ('completed', 'cancelled') and new.ended_at is null then
    raise exception 'Terminal focus sessions require ended_at';
  end if;

  if new.ended_at is not null then
    v_elapsed_seconds := extract(epoch from (new.ended_at - new.started_at))::integer;
  else
    v_elapsed_seconds := extract(epoch from (clock_timestamp() - new.started_at))::integer;
  end if;
  if new.active_duration_seconds > greatest(v_elapsed_seconds, 0) then
    raise exception 'Active duration cannot exceed elapsed session time';
  end if;

  new.updated_at = clock_timestamp();
  return new;
end;
$$;
