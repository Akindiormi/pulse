begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

select has_table(
  'public', 'projects',
  'projects table exists'
);
select has_column(
  'public', 'projects', 'user_id',
  'projects are owned by a profile'
);
select has_column(
  'public', 'projects', 'name',
  'projects have a required name'
);
select has_column(
  'public', 'projects', 'status',
  'projects have an explicit lifecycle status'
);
select is(
  (select column_default from information_schema.columns
   where table_schema = 'public' and table_name = 'projects' and column_name = 'status'),
  '''active''::text',
  'new projects default to active'
);
select is(
  (select is_nullable from information_schema.columns
   where table_schema = 'public' and table_name = 'tasks' and column_name = 'milestone_id'),
  'YES',
  'task milestone_id remains nullable for unmilestoned tasks'
);
select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class child on child.oid = c.conrelid
    join pg_class parent on parent.oid = c.confrelid
    join pg_namespace n on n.oid = child.relnamespace
    where n.nspname = 'public'
      and child.relname = 'tasks'
      and parent.relname = 'projects'
      and c.contype = 'f'
      and c.confdeltype = 'c'
  ),
  'deleting a project cascades its tasks'
);
select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public' and tablename = 'projects'
      and policyname = 'users can read their projects'
  ),
  'project select policy is owner-scoped'
);
select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public' and tablename = 'projects'
      and policyname = 'users can create their projects'
  ),
  'project insert policy is owner-scoped'
);
select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public' and tablename = 'projects'
      and policyname = 'users can update their projects'
  ),
  'project update policy is owner-scoped'
);
select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public' and tablename = 'projects'
      and policyname = 'users can delete their projects'
  ),
  'project delete policy is owner-scoped'
);
select ok(
  to_regclass('public.projects_user_status_idx') is not null,
  'projects have a user/status index for listing'
);

select * from finish();
rollback;
