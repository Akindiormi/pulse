-- Slice 4: Focus database foundation.
--
-- Focus is an independent persisted work-session subsystem.
-- The database stores the authoritative accumulated focused time in
-- active_duration_seconds. The Flutter timer is only a projection of this
-- persisted state and is not the source of truth.
--
-- Lifecycle:
--   running -> paused -> running -> completed
--   running -> completed
--   running -> cancelled
--   paused  -> completed
--   paused  -> cancelled
-- Terminal sessions retain their historical row. A task is optional and is
-- deliberately SET NULL on task deletion so historical Focus data survives.

create table public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_id uuid references public.tasks(id) on delete set null,
  status text not null default 'running'
    check (status in ('running', 'paused', 'completed', 'cancelled')),
  planned_duration_seconds integer not null
    check (planned_duration_seconds > 0),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  active_duration_seconds integer not null default 0
    check (active_duration_seconds >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint focus_sessions_time_order
    check (ended_at is null or ended_at >= started_at),
  constraint focus_sessions_lifecycle_timestamps
    check (
      (status in ('running', 'paused') and ended_at is null)
      or
      (status in ('completed', 'cancelled') and ended_at is not null)
    ),
  constraint focus_sessions_terminal_duration_bound
    check (
      ended_at is null
      or active_duration_seconds <= extract(epoch from (ended_at - started_at))::integer
    )
);

create index focus_sessions_user_started_idx
  on public.focus_sessions(user_id, started_at desc);

create index focus_sessions_user_status_idx
  on public.focus_sessions(user_id, status, started_at desc);

create index focus_sessions_task_idx
  on public.focus_sessions(task_id, started_at desc)
  where task_id is not null;

-- Keep the accumulated active time monotonic and prevent impossible lifecycle
-- transitions. Wall-clock time is used only as an upper bound; accumulated
-- active time remains the authoritative measure of actual focused work.
create or replace function public.validate_focus_session_transition()
returns trigger
language plpgsql
as $$
declare
  v_elapsed_seconds integer;
begin
  if tg_op = 'UPDATE' then
    if old.status in ('completed', 'cancelled') and new.status <> old.status then
      raise exception 'Terminal focus sessions cannot change lifecycle state';
    end if;

    if old.status = 'running' and new.status not in ('running', 'paused', 'completed', 'cancelled') then
      raise exception 'Invalid focus session transition';
    end if;

    if old.status = 'paused' and new.status not in ('paused', 'running', 'completed', 'cancelled') then
      raise exception 'Invalid focus session transition';
    end if;

    if new.active_duration_seconds < old.active_duration_seconds then
      raise exception 'Active duration cannot decrease';
    end if;
  end if;

  if new.active_duration_seconds < 0 then
    raise exception 'Active duration cannot be negative';
  end if;

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

drop trigger if exists focus_sessions_validate_transition on public.focus_sessions;
create trigger focus_sessions_validate_transition
before insert or update on public.focus_sessions
for each row execute function public.validate_focus_session_transition();

alter table public.focus_sessions enable row level security;

create policy "users can read their focus sessions" on public.focus_sessions
  for select to authenticated
  using (user_id = auth.uid());

create policy "users can create their focus sessions" on public.focus_sessions
  for insert to authenticated
  with check (user_id = auth.uid());

create policy "users can update their focus sessions" on public.focus_sessions
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "users can delete their focus sessions" on public.focus_sessions
  for delete to authenticated
  using (user_id = auth.uid());

revoke all on public.focus_sessions from anon;
grant select, insert, update, delete on public.focus_sessions to authenticated;
grant all on public.focus_sessions to service_role;

grant execute on function public.validate_focus_session_transition() to authenticated;

grant execute on function public.validate_focus_session_transition() to service_role;

comment on table public.focus_sessions is 'Persisted intentional work sessions. active_duration_seconds is the authoritative accumulated focused-work duration.';
comment on column public.focus_sessions.active_duration_seconds is 'Authoritative accumulated active focus time; UI timer is a projection of persisted state.';
comment on column public.focus_sessions.task_id is 'Optional task association. Deleting a task preserves this Focus session and clears task_id.';
comment on column public.focus_sessions.status is 'Lifecycle state: running, paused, completed, or cancelled.';
