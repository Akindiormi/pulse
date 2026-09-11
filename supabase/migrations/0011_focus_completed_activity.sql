-- Slice 4F: completed Focus sessions produce the reserved typed activity event.
-- Only a terminal completion qualifies. Cancellation produces no activity.

create unique index if not exists activity_events_focus_completion_idx
  on public.activity_events(user_id, event_type, entity_id)
  where event_type = 'focus_completed' and entity_id is not null;

create or replace function public.record_focus_completed_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := timezone('utc', clock_timestamp())::date;
  v_profile public.profiles%rowtype;
  v_new_streak integer;
  v_window_activity_count integer := 0;
  v_window_start date := v_today - 6;
begin
  if old.status <> 'completed' and new.status = 'completed' then
    insert into public.activity_events(user_id, event_type, entity_id, occurred_at, activity_date, metadata)
    values(new.user_id, 'focus_completed', new.id, clock_timestamp(), v_today,
           jsonb_build_object('source', 'focus_completion', 'activeDurationSeconds', new.active_duration_seconds))
    on conflict (user_id, event_type, entity_id) where event_type = 'focus_completed' and entity_id is not null do nothing;

    select * into v_profile from public.profiles where id = new.user_id for update;
    if found then
      if v_profile.last_activity_date is null then
        v_new_streak := 1;
      elsif v_profile.last_activity_date = v_today then
        v_new_streak := greatest(v_profile.current_streak, 1);
      elsif v_profile.last_activity_date = v_today - 1 then
        v_new_streak := v_profile.current_streak + 1;
      else
        select count(distinct activity_date) into v_window_activity_count
        from public.activity_events
        where user_id = new.user_id
          and activity_date >= v_window_start
          and activity_date < v_today
          and activity_date > v_profile.last_activity_date;

        if v_profile.last_activity_date = v_today - 2 and v_window_activity_count >= 1 then
          v_new_streak := v_profile.current_streak + 1;
        else
          v_new_streak := 1;
        end if;
      end if;

      update public.profiles
      set current_streak = v_new_streak,
          longest_streak = greatest(v_profile.longest_streak, v_new_streak),
          total_activities = v_profile.total_activities + 1,
          last_activity_date = v_today
      where id = new.user_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists focus_completed_activity on public.focus_sessions;
create trigger focus_completed_activity
after update on public.focus_sessions
for each row execute function public.record_focus_completed_activity();

revoke all on function public.record_focus_completed_activity() from public, anon;
grant execute on function public.record_focus_completed_activity() to authenticated, service_role;
