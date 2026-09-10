begin;

create extension if not exists pgtap with schema extensions;

select plan(46);

-- Schema contract.
select has_table('public', 'task_series', 'task series table exists');
select has_column('public', 'task_series', 'user_id', 'task series are owner-scoped');
select has_column('public', 'task_series', 'recurrence_type', 'task series store a bounded recurrence type');
select has_column('public', 'task_series', 'recurrence_interval', 'task series store recurrence interval');
select has_column('public', 'task_series', 'timezone', 'task series store an explicit schedule timezone');
select has_column('public', 'task_series', 'starts_at', 'task series have a schedule start');
select has_column('public', 'task_series', 'until_at', 'task series support an optional end boundary');
select has_column('public', 'task_series', 'occurrence_count', 'task series support an optional occurrence count');
select has_column('public', 'task_series', 'is_active', 'task series can be stopped without deleting history');
select has_column('public', 'tasks', 'task_series_id', 'normal tasks can optionally belong to a series');
select has_column('public', 'tasks', 'occurrence_key', 'recurring tasks have a deterministic occurrence identity');
select has_column('public', 'tasks', 'first_completed_at', 'tasks preserve first completion history across reopen');
select is((select is_nullable from information_schema.columns where table_schema='public' and table_name='tasks' and column_name='task_series_id'), 'YES', 'existing normal tasks remain valid with a nullable series reference');
select is((select is_nullable from information_schema.columns where table_schema='public' and table_name='tasks' and column_name='occurrence_key'), 'YES', 'existing normal tasks remain valid with a nullable occurrence identity');
select ok(to_regclass('public.tasks_series_occurrence_idx') is not null, 'recurring occurrence identity has a unique index');
select ok(exists (select 1 from pg_index i join pg_class c on c.oid=i.indexrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='tasks_series_occurrence_idx' and i.indisunique), 'recurring occurrence identity index is unique');

-- Ownership and relationship integrity.
select ok(exists (select 1 from pg_policies where schemaname='public' and tablename='task_series' and policyname='users can read their task series'), 'task series select is owner-scoped');
select ok(exists (select 1 from pg_policies where schemaname='public' and tablename='task_series' and policyname='users can create their task series'), 'task series insert is owner-scoped');
select ok(exists (select 1 from pg_policies where schemaname='public' and tablename='task_series' and policyname='users can update their task series'), 'task series update is owner-scoped');
select ok(exists (select 1 from pg_policies where schemaname='public' and tablename='task_series' and policyname='users can delete their task series'), 'task series delete is owner-scoped');
select ok(to_regprocedure('public.validate_task_series_ownership()') is not null, 'task-to-series ownership trigger function exists');
select ok(to_regprocedure('public.validate_task_series_project_milestone()') is not null, 'series project/milestone ownership trigger function exists');

-- Server-authoritative lifecycle boundaries.
select has_function('public', 'reopen_task', ARRAY['uuid'], 'reopen_task RPC exists');
select is_definer('public', 'reopen_task', ARRAY['uuid'], 'reopen_task remains backend-authoritative');
select matches(pg_get_functiondef('public.reopen_task(uuid)'::regprocedure), 'for update', 'reopen_task locks the task row before changing lifecycle state');
select matches(pg_get_functiondef('public.reopen_task(uuid)'::regprocedure), 'user_id = v_uid', 'reopen_task verifies task ownership inside the server function');
select matches(pg_get_functiondef('public.reopen_task(uuid)'::regprocedure), 'completed_at = null', 'reopen_task clears current completion state while preserving first completion history');
select matches(pg_get_functiondef('public.reopen_task(uuid)'::regprocedure), 'first_completed_at', 'reopen_task returns preserved first completion history');
select matches(pg_get_functiondef('public.reopen_task(uuid)'::regprocedure), 'TASK_CANCELLED', 'reopen_task rejects cancelled tasks');
select matches(pg_get_functiondef('public.reopen_task(uuid)'::regprocedure), 'reopened.*false.*alreadyOpen', 'reopen_task is idempotent when the task is already open');

-- Reward identity and transaction/concurrency contract.
select has_function('public', 'complete_task', ARRAY['uuid'], 'lifecycle-aware complete_task RPC exists');
select is_definer('public', 'complete_task', ARRAY['uuid'], 'complete_task remains backend-authoritative');
select matches(pg_get_functiondef('public.complete_task(uuid)'::regprocedure), 'for update', 'complete_task still locks task/profile rows for retry serialization');
select matches(pg_get_functiondef('public.complete_task(uuid)'::regprocedure), 'v_existing_event_id', 'complete_task checks durable completion history before rewarding');
select matches(pg_get_functiondef('public.complete_task(uuid)'::regprocedure), 'alreadyRewarded', 'complete_task exposes the historical reward identity outcome');
select matches(pg_get_functiondef('public.complete_task(uuid)'::regprocedure), 'xpAwarded.*0', 'repeat completion path returns zero additional XP');
select matches(pg_get_functiondef('public.complete_task(uuid)'::regprocedure), 'activity_events', 'completion reward authority still records typed completion history');
select matches(pg_get_functiondef('public.complete_task(uuid)'::regprocedure), 'TASK_CANCELLED', 'complete_task still rejects cancelled tasks');
select ok(to_regprocedure('public.ensure_task_occurrence(uuid,timestamptz)') is not null, 'server-side occurrence generation RPC exists');
select is_definer('public', 'ensure_task_occurrence', ARRAY['uuid','timestamp with time zone'], 'occurrence generation is backend-authoritative');
select matches(pg_get_functiondef('public.ensure_task_occurrence(uuid,timestamptz)'::regprocedure), 'on conflict \(task_series_id, occurrence_key\) do nothing', 'occurrence generation is race-safe at insertion');
select matches(pg_get_functiondef('public.ensure_task_occurrence(uuid,timestamptz)'::regprocedure), 'TASK_SERIES_NOT_FOUND', 'occurrence generation verifies series ownership/existence');
select matches(pg_get_functiondef('public.ensure_task_occurrence(uuid,timestamptz)'::regprocedure), 'OCCURRENCE_COUNT_EXCEEDED', 'occurrence generation enforces the optional count boundary');
select matches(pg_get_functiondef('public.ensure_task_occurrence(uuid,timestamptz)'::regprocedure), 'OCCURRENCE_AFTER_SERIES_END', 'occurrence generation enforces the optional until boundary');

-- The new task path remains separate from the legacy Firestore-shaped challenge path.
select ok(position('complete_challenge' in pg_get_functiondef('public.complete_task(uuid)'::regprocedure)) = 0, 'task completion does not call the legacy challenge reward path');
select ok(position('public.activities' in pg_get_functiondef('public.complete_task(uuid)'::regprocedure)) = 0, 'task completion does not write the legacy challenge activities table');

select * from finish();
rollback;
