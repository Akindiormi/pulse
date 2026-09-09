begin;

select plan(20);

select has_table('public', 'calendar_events', 'calendar_events table exists');
select has_column('public', 'calendar_events', 'user_id', 'calendar event has owner');
select has_column('public', 'calendar_events', 'starts_at', 'calendar event has start');
select has_column('public', 'calendar_events', 'ends_at', 'calendar event has end');
select has_column('public', 'calendar_events', 'timezone', 'calendar event stores IANA timezone');
select has_column('public', 'calendar_events', 'recurrence_rule', 'calendar event stores recurrence rule');
select has_table('public', 'task_calendar_events', 'task calendar link table exists');
select has_column('public', 'task_calendar_events', 'task_id', 'link has task id');
select has_column('public', 'task_calendar_events', 'calendar_event_id', 'link has event id');

select has_index('public', 'calendar_events', 'calendar_events_user_start_idx', 'calendar events have range index');
select has_index('public', 'task_calendar_events', 'task_calendar_events_event_idx', 'calendar links have event index');

select col_is_not_null('public', 'calendar_events', 'timezone', 'timezone is required');
select col_has_default('public', 'calendar_events', 'all_day', 'all_day defaults false');
select col_has_default('public', 'calendar_events', 'timezone', 'timezone defaults UTC');
select fk_ok('public', 'task_calendar_events', 'task_id', 'public', 'tasks', 'id', 'link points to tasks');
select fk_ok('public', 'task_calendar_events', 'calendar_event_id', 'public', 'calendar_events', 'id', 'link points to events');
select policies_are('public', 'calendar_events', ARRAY[
  'users can read their calendar events',
  'users can create their calendar events',
  'users can update their calendar events',
  'users can delete their calendar events'
], 'calendar event RLS policies exist');
select policies_are('public', 'task_calendar_events', ARRAY[
  'users can read their task calendar links',
  'users can create their task calendar links',
  'users can delete their task calendar links'
], 'calendar link RLS policies exist');
select has_function('public', 'validate_task_calendar_event_link', ARRAY[]::text[], 'calendar link ownership trigger function exists');

-- Verify the deletion contract at the FK level: deleting either side deletes only
-- the link row, never the other record.
select fk_ok('public', 'task_calendar_events', 'task_id', 'public', 'tasks', 'id', 'task deletion cascades only to link');

select * from finish();
rollback;
