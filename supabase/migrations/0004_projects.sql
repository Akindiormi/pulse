-- Slice 2A: project foundation.
--
-- Clock decision:
--   Task scheduling and Today use the user's device-local calendar day.
--   Streak authority uses the server UTC calendar day.
--   These are two different clocks by design, not an inconsistency.
--
-- Deletion contract for the upcoming milestone/project slices:
--   Deleting a milestone keeps its tasks and clears milestone_id, leaving them
--   attached to the project as unmilestoned tasks.
--   Deleting a project cascades its milestones and all project tasks.
--
-- Progress contract:
--   Project progress is completed tasks / total tasks * 100.
--   Empty milestones contribute no tasks and therefore do not affect progress.
--
-- Activity contract:
--   Completing any task, including a project task, emits the same task_completed
--   event. Milestone/project completion events are separate typed events and are
--   not compound events emitted by task completion in this slice.

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 200),
  description text,
  status text not null default 'active' check (status in ('active', 'completed', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index projects_user_status_idx on public.projects(user_id, status, updated_at desc);

alter table public.tasks
  add constraint tasks_project_id_fkey
  foreign key (project_id) references public.projects(id) on delete cascade;

-- A milestone is not created in 2A; this constraint is added now so the
-- eventual milestone table can own the relationship with the agreed deletion
-- semantics without leaving project tasks orphaned at the database level.
-- milestone_id remains nullable until Slice 2B creates public.milestones.

alter table public.projects enable row level security;

create policy "users can read their projects" on public.projects
  for select to authenticated using (user_id = auth.uid());
create policy "users can create their projects" on public.projects
  for insert to authenticated with check (user_id = auth.uid());
create policy "users can update their projects" on public.projects
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "users can delete their projects" on public.projects
  for delete to authenticated using (user_id = auth.uid());

grant select, insert, update, delete on public.projects to authenticated;
grant all on public.projects to service_role;

create or replace function public.set_project_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists projects_set_updated_at on public.projects;
create trigger projects_set_updated_at
before update on public.projects
for each row execute function public.set_project_updated_at();

comment on table public.projects is 'Slice 2 project foundation: create, list, open, and overview. Progress is derived from tasks.';
comment on column public.projects.status is 'Project lifecycle: active, completed, or archived.';
comment on constraint tasks_project_id_fkey on public.tasks is 'Project deletion cascades project tasks.';
