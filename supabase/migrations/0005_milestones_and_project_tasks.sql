-- Slice 2B-2D: milestones, project task assignment, and progress integrity.

create table public.milestones (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 200),
  description text,
  status text not null default 'active' check (status in ('active', 'completed', 'archived')),
  due_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index milestones_project_idx on public.milestones(project_id, status, due_date, created_at);
create index milestones_user_idx on public.milestones(user_id, updated_at desc);

alter table public.tasks
  add constraint tasks_milestone_id_fkey
  foreign key (milestone_id) references public.milestones(id) on delete set null;

-- A task may only point at a milestone belonging to the same project.
create or replace function public.validate_task_milestone_project()
returns trigger language plpgsql as $$
begin
  if new.milestone_id is not null then
    if new.project_id is null then
      raise exception 'A milestone task must belong to a project';
    end if;
    if not exists (
      select 1 from public.milestones m
      where m.id = new.milestone_id
        and m.project_id = new.project_id
        and m.user_id = new.user_id
    ) then
      raise exception 'Milestone does not belong to the task project';
    end if;
  end if;
  if new.project_id is not null then
    if not exists (
      select 1 from public.projects p
      where p.id = new.project_id and p.user_id = new.user_id
    ) then
      raise exception 'Project does not belong to the task owner';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists tasks_validate_project_milestone on public.tasks;
create trigger tasks_validate_project_milestone
before insert or update of user_id, project_id, milestone_id on public.tasks
for each row execute function public.validate_task_milestone_project();

alter table public.milestones enable row level security;

create policy "users can read their milestones" on public.milestones
  for select to authenticated
  using (user_id = auth.uid());
create policy "users can create milestones in their projects" on public.milestones
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.projects p where p.id = project_id and p.user_id = auth.uid())
  );
create policy "users can update their milestones" on public.milestones
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.projects p where p.id = project_id and p.user_id = auth.uid())
  );
create policy "users can delete their milestones" on public.milestones
  for delete to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on public.milestones to authenticated;
grant all on public.milestones to service_role;

drop trigger if exists milestones_set_updated_at on public.milestones;
create trigger milestones_set_updated_at
before update on public.milestones
for each row execute function public.set_project_updated_at();

comment on table public.milestones is 'Project milestones. Deleting a milestone preserves its project tasks and clears milestone_id.';
comment on constraint tasks_milestone_id_fkey on public.tasks is 'Milestone deletion keeps the task in the project as an unmilestoned Other task.';
