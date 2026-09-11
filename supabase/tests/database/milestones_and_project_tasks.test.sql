begin;

create extension if not exists pgtap with schema extensions;
select plan(16);

select has_table('public', 'milestones', 'milestones table exists');
select has_column('public', 'milestones', 'project_id', 'milestones belong to projects');
select has_column('public', 'milestones', 'user_id', 'milestones have an owner');
select has_column('public', 'milestones', 'name', 'milestones have a name');
select has_column('public', 'milestones', 'due_date', 'milestones can have a deadline');
select ok(exists (select 1 from pg_policies where schemaname='public' and tablename='milestones' and policyname='users can read their milestones'), 'milestone select is owner-scoped');
select ok(exists (select 1 from pg_policies where schemaname='public' and tablename='milestones' and policyname='users can create milestones in their projects'), 'milestone insert requires project ownership');
select ok(exists (select 1 from pg_policies where schemaname='public' and tablename='milestones' and policyname='users can update their milestones'), 'milestone update is owner-scoped');
select ok(exists (select 1 from pg_policies where schemaname='public' and tablename='milestones' and policyname='users can delete their milestones'), 'milestone delete is owner-scoped');
select ok(exists (select 1 from pg_constraint c join pg_class child on child.oid=c.conrelid join pg_class parent on parent.oid=c.confrelid where child.relname='milestones' and parent.relname='projects' and c.contype='f' and c.confdeltype='c'), 'project deletion cascades milestones');
select ok(exists (select 1 from pg_constraint c join pg_class child on child.oid=c.conrelid join pg_class parent on parent.oid=c.confrelid where child.relname='tasks' and parent.relname='milestones' and c.contype='f' and c.confdeltype='n'), 'milestone deletion uses SET NULL for task milestone');
select ok(to_regprocedure('public.validate_task_milestone_project()') is not null, 'task milestone/project integrity trigger exists');
select ok(to_regclass('public.milestones_project_idx') is not null, 'milestones have a project index');
select is((select column_default from information_schema.columns where table_schema='public' and table_name='milestones' and column_name='status'), '''active''::text', 'milestones default to active');
select ok(exists (select 1 from pg_constraint where conrelid='public.milestones'::regclass and contype='c' and pg_get_constraintdef(oid) like '%active%completed%archived%'), 'milestone status has an explicit lifecycle check');
select ok(exists (select 1 from pg_trigger where tgrelid='public.milestones'::regclass and tgname='milestones_set_updated_at'), 'milestone updates refresh updated_at');

select * from finish();
rollback;
