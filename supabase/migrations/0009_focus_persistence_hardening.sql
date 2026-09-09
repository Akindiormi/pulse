-- Slice 4 Phase 3: server-authoritative Focus persistence hardening.
-- PostgreSQL calculates active time from the previous persisted lifecycle timestamp.
-- v1 permits at most one active Focus session (running or paused) per user.

create unique index focus_sessions_one_active_per_user_idx
  on public.focus_sessions(user_id)
  where status in ('running', 'paused');

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

  if tg_op = 'UPDATE' then
    if new.user_id <> old.user_id then raise exception 'Focus session owner cannot change'; end if;
    if old.status in ('completed', 'cancelled') and new.status <> old.status then
      raise exception 'Terminal focus sessions cannot change lifecycle state';
    end if;
    if old.status = 'running' and new.status not in ('running', 'paused', 'completed', 'cancelled') then
      raise exception 'Invalid focus session transition';
    end if;
    if old.status = 'paused' and new.status not in ('paused', 'running', 'completed', 'cancelled') then
      raise exception 'Invalid focus session transition';
    end if;

    if old.status = 'running' then
      v_elapsed_seconds := greatest(extract(epoch from (now() - old.updated_at))::integer, 0);
      new.active_duration_seconds := old.active_duration_seconds + v_elapsed_seconds;
    elsif new.active_duration_seconds < old.active_duration_seconds then
      raise exception 'Active duration cannot decrease';
    end if;
  end if;

  if new.active_duration_seconds < 0 then raise exception 'Active duration cannot be negative'; end if;
  if new.status in ('running', 'paused') and new.ended_at is not null then
    raise exception 'Active focus sessions cannot have an ended_at timestamp';
  end if;
  if new.status in ('completed', 'cancelled') and new.ended_at is null then
    raise exception 'Terminal focus sessions require ended_at';
  end if;
  if new.ended_at is not null and new.ended_at < new.started_at then
    raise exception 'ended_at cannot be before started_at';
  end if;

  if new.ended_at is not null then
    v_elapsed_seconds := extract(epoch from (new.ended_at - new.started_at))::integer;
  else
    v_elapsed_seconds := extract(epoch from (now() - new.started_at))::integer;
  end if;
  if new.active_duration_seconds > greatest(v_elapsed_seconds, 0) then
    raise exception 'Active duration cannot exceed elapsed session time';
  end if;

  new.updated_at = now();
  return new;
end;
$$;

comment on index public.focus_sessions_one_active_per_user_idx is
  'Prevents a user from having more than one running or paused Focus session.';
