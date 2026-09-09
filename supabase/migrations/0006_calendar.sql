-- Slice 3: Calendar foundation.
--
-- Recurrence decision:
--   A recurring event stores one RRULE-style recurrence_rule on the series row.
--   Occurrences are generated virtually only for the requested/visible calendar
--   range. Open-ended recurrence is never expanded indefinitely or materialized.
--   Slice 3 v1 supports series-level editing only; per-occurrence exceptions
--   and overrides are explicitly out of scope.
--
-- Scheduling decision:
--   tasks.due_date remains a deadline used by Today. Calendar scheduling is a
--   separate task <-> calendar event relationship. Both records can exist alone.
--
-- Focus decision:
--   Focus remains calendar-agnostic. Starting Focus from a linked calendar event
--   passes its task_id; Focus does not depend on Calendar.
--
-- Independence/deletion decision:
--   Deleting a task preserves its calendar event(s) and removes only the link.
--   Deleting a calendar event preserves its task and removes only the link.
--
-- Clock decision:
--   Calendar timestamps represent instants, while timezone stores the IANA
--   timezone used for local wall-clock recurrence generation and display.

create table public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 200),
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  all_day boolean not null default false,
  timezone text not null default 'UTC' check (char_length(trim(timezone)) between 1 and 100),
  recurrence_rule text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint calendar_events_time_order check (ends_at > starts_at),
  constraint calendar_events_rrule_length check (recurrence_rule is null or char_length(recurrence_rule) between 1 and 2000)
);

create index calendar_events_user_start_idx
  on public.calendar_events(user_id, starts_at, ends_at);
create index calendar_events_user_updated_idx
  on public.calendar_events(user_id, updated_at desc);

create table public.task_calendar_events (
  task_id uuid not null references public.tasks(id) on delete cascade,
  calendar_event_id uuid not null references public.calendar_events(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (task_id, calendar_event_id)
);

create index task_calendar_events_event_idx
  on public.task_calendar_events(calendar_event_id, task_id);

-- Links are owner-scoped on both sides. This prevents cross-user task/event links.
create or replace function public.validate_task_calendar_event_link()
returns trigger language plpgsql as $$
begin
  if not exists (
    select 1 from public.tasks t
    where t.id = new.task_id and t.user_id = auth.uid()
  ) then
    raise exception 'Task does not belong to the current user';
  end if;
  if not exists (
    select 1 from public.calendar_events e
    where e.id = new.calendar_event_id and e.user_id = auth.uid()
  ) then
    raise exception 'Calendar event does not belong to the current user';
  end if;
  return new;
end;
$$;

create trigger task_calendar_events_owner_check
before insert or update on public.task_calendar_events
for each row execute function public.validate_task_calendar_event_link();

alter table public.calendar_events enable row level security;
alter table public.task_calendar_events enable row level security;

create policy "users can read their calendar events" on public.calendar_events
  for select to authenticated using (user_id = auth.uid());
create policy "users can create their calendar events" on public.calendar_events
  for insert to authenticated with check (user_id = auth.uid());
create policy "users can update their calendar events" on public.calendar_events
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "users can delete their calendar events" on public.calendar_events
  for delete to authenticated using (user_id = auth.uid());

grant select, insert, update, delete on public.calendar_events to authenticated;
grant all on public.calendar_events to service_role;

drop trigger if exists calendar_events_set_updated_at on public.calendar_events;
create trigger calendar_events_set_updated_at
before update on public.calendar_events
for each row execute function public.set_project_updated_at();

create policy "users can read their task calendar links" on public.task_calendar_events
  for select to authenticated
  using (
    exists (select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid())
    and exists (select 1 from public.calendar_events e where e.id = calendar_event_id and e.user_id = auth.uid())
  );
create policy "users can create their task calendar links" on public.task_calendar_events
  for insert to authenticated
  with check (
    exists (select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid())
    and exists (select 1 from public.calendar_events e where e.id = calendar_event_id and e.user_id = auth.uid())
  );
create policy "users can delete their task calendar links" on public.task_calendar_events
  for delete to authenticated
  using (
    exists (select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid())
    and exists (select 1 from public.calendar_events e where e.id = calendar_event_id and e.user_id = auth.uid())
  );

grant select, insert, delete on public.task_calendar_events to authenticated;
grant all on public.task_calendar_events to service_role;

comment on table public.calendar_events is 'Calendar series/event rows. Recurrence occurrences are virtual and range-bounded on read.';
comment on column public.calendar_events.recurrence_rule is 'RRULE-style series definition; v1 edits the whole series and has no occurrence exceptions.';
comment on column public.calendar_events.timezone is 'IANA timezone for local wall-clock display and recurrence expansion.';
comment on table public.task_calendar_events is 'Independent task-to-calendar scheduling links. Deleting either side removes only the link.';
