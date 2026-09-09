create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text,
  display_name text,
  photo_url text,
  timezone text,
  notification_preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  total_activities integer not null default 0 check (total_activities >= 0),
  current_streak integer not null default 0 check (current_streak >= 0),
  longest_streak integer not null default 0 check (longest_streak >= 0),
  xp bigint not null default 0 check (xp >= 0),
  level integer not null default 1 check (level >= 1),
  last_activity_date date,
  completed_categories text[] not null default '{}',
  unlocked_achievements text[] not null default '{}'
);

create table public.challenges (
  id text primary key,
  title text not null,
  description text not null,
  category text not null,
  difficulty text not null,
  xp_reward integer not null check (xp_reward >= 0 and xp_reward <= 1000),
  estimated_minutes integer not null default 0 check (estimated_minutes >= 0),
  estimated_cost numeric,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.daily_challenges (
  user_id uuid not null references public.profiles(id) on delete cascade,
  date date not null,
  challenge_id text not null references public.challenges(id),
  assigned_at timestamptz not null default now(),
  completed_at timestamptz,
  completed boolean not null default false,
  source text not null default 'server' check (source = 'server'),
  assignment_version integer not null default 1,
  primary key (user_id, date)
);

create table public.activities (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  challenge_id text not null references public.challenges(id),
  date date not null,
  xp_awarded integer not null check (xp_awarded >= 0),
  completed_at timestamptz not null default now(),
  category text
);
create unique index activities_user_day_challenge_idx on public.activities(user_id, date, challenge_id);

create table public.achievements (
  user_id uuid not null references public.profiles(id) on delete cascade,
  achievement_id text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

create index daily_challenges_user_date_idx on public.daily_challenges(user_id, date desc);
create index activities_user_completed_idx on public.activities(user_id, completed_at desc);
create index achievements_user_idx on public.achievements(user_id);

alter table public.profiles enable row level security;
alter table public.challenges enable row level security;
alter table public.daily_challenges enable row level security;
alter table public.activities enable row level security;
alter table public.achievements enable row level security;

create policy "users can read their profile" on public.profiles for select to authenticated using (id = auth.uid());
create policy "users can update their profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "users can insert their profile" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "authenticated users can read active challenges" on public.challenges for select to authenticated using (active = true);
create policy "users can read their daily assignments" on public.daily_challenges for select to authenticated using (user_id = auth.uid());
create policy "users can read their activities" on public.activities for select to authenticated using (user_id = auth.uid());
create policy "users can read their achievements" on public.achievements for select to authenticated using (user_id = auth.uid());

revoke all on public.profiles, public.challenges, public.daily_challenges, public.activities, public.achievements from anon;
grant select, insert, update on public.profiles to authenticated;
grant select on public.challenges, public.daily_challenges, public.activities, public.achievements to authenticated;
grant all on public.profiles, public.challenges, public.daily_challenges, public.activities, public.achievements to service_role;

do $$
begin
  if not exists (select 1 from pg_proc where proname = 'handle_new_user') then
    create function public.handle_new_user()
    returns trigger
    language plpgsql
    security definer set search_path = public
    as $fn$
    begin
      insert into public.profiles (id, display_name, username)
      values (new.id, nullif(new.raw_user_meta_data ->> 'display_name', ''), nullif(new.raw_user_meta_data ->> 'username', ''))
      on conflict (id) do nothing;
      return new;
    end;
    $fn$;
  end if;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.level_for_xp(p_xp bigint)
returns integer
language plpgsql
immutable
as $$
declare
  thresholds bigint[] := array[0,100,250,450,700,1000,1400,1850,2350,2900];
  result integer := 1;
  i integer;
begin
  for i in 1..array_length(thresholds, 1) loop
    if p_xp >= thresholds[i] then result := i; end if;
  end loop;
  if p_xp >= thresholds[array_length(thresholds, 1)] then
    result := array_length(thresholds, 1) + floor((p_xp - thresholds[array_length(thresholds, 1)]) / 650.0)::integer;
  end if;
  return result;
end;
$$;

create or replace function public.get_or_assign_daily_challenge(p_uid uuid)
returns table(date text, challenge_id text, completed boolean, assigned_at timestamptz)
language plpgsql
security definer set search_path = public
as $$
declare
  v_date date := timezone('utc', now())::date;
  v_assignment public.daily_challenges%rowtype;
  v_challenge public.challenges%rowtype;
  v_offset integer;
  v_count integer;
begin
  if not exists (select 1 from public.profiles where id = p_uid) then
    raise exception 'PROFILE_NOT_FOUND' using errcode = 'P0001';
  end if;

  select * into v_assignment from public.daily_challenges where user_id = p_uid and public.daily_challenges.date = v_date for update;
  if found then
    select * into v_challenge from public.challenges where id = v_assignment.challenge_id and active = true;
    if not found then raise exception 'CHALLENGE_UNAVAILABLE' using errcode = 'P0001'; end if;
    return query select v_date::text, v_assignment.challenge_id, v_assignment.completed, v_assignment.assigned_at;
    return;
  end if;

  select count(*) into v_count from public.challenges where active = true;
  if v_count = 0 then raise exception 'NO_ACTIVE_CHALLENGES' using errcode = 'P0001'; end if;
  v_offset := ('x' || substr(md5(v_date::text), 1, 8))::bit(32)::bigint % v_count;
  select * into v_challenge from public.challenges where active = true order by id offset v_offset limit 1;

  insert into public.daily_challenges(user_id, date, challenge_id, assigned_at, completed, source, assignment_version)
  values (p_uid, v_date, v_challenge.id, now(), false, 'server', 1)
  returning * into v_assignment;

  return query select v_date::text, v_assignment.challenge_id, false, v_assignment.assigned_at;
end;
$$;

create or replace function public.complete_challenge(p_uid uuid)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  v_date date := timezone('utc', now())::date;
  v_user public.profiles%rowtype;
  v_assignment public.daily_challenges%rowtype;
  v_challenge public.challenges%rowtype;
  v_existing public.activities%rowtype;
  v_previous_xp bigint;
  v_previous_streak integer;
  v_previous_level integer;
  v_current_streak integer;
  v_longest_streak integer;
  v_total_activities integer;
  v_next_xp bigint;
  v_next_level integer;
  v_challenge_xp integer;
  v_achievement_xp integer := 0;
  v_total_reward integer;
  v_new_achievements text[] := '{}';
  v_categories text[];
  v_unlocked text[];
  v_next_categories text[];
  v_next_unlocked text[];
  v_category_count integer;
  v_day_gap integer;
  v_achievement text;
  v_reward integer;
  v_threshold integer;
  v_eligible boolean;
begin
  select * into v_user from public.profiles where id = p_uid for update;
  if not found then raise exception 'PROFILE_NOT_FOUND' using errcode = 'P0001'; end if;

  select * into v_assignment from public.daily_challenges where user_id = p_uid and date = v_date for update;
  if not found then
    perform * from public.get_or_assign_daily_challenge(p_uid);
    select * into v_assignment from public.daily_challenges where user_id = p_uid and date = v_date for update;
  end if;

  select * into v_challenge from public.challenges where id = v_assignment.challenge_id;
  if not found or v_challenge.active is not true then raise exception 'CHALLENGE_UNAVAILABLE' using errcode = 'P0001'; end if;

  select * into v_existing from public.activities where user_id = p_uid and date = v_date and challenge_id = v_assignment.challenge_id for update;
  if found or v_assignment.completed then
    return jsonb_build_object(
      'completed', false, 'alreadyCompleted', true, 'challengeId', v_assignment.challenge_id,
      'xpAwarded', 0, 'challengeXP', 0, 'achievementXP', 0,
      'previousXP', v_user.xp, 'currentXP', v_user.xp,
      'previousStreak', v_user.current_streak, 'currentStreak', v_user.current_streak,
      'longestStreak', v_user.longest_streak, 'previousLevel', v_user.level,
      'newLevel', v_user.level, 'leveledUp', false, 'newAchievements', '[]'::jsonb
    );
  end if;

  v_challenge_xp := v_challenge.xp_reward;
  v_previous_xp := v_user.xp;
  v_previous_streak := v_user.current_streak;
  v_previous_level := v_user.level;
  v_total_activities := v_user.total_activities + 1;
  v_categories := coalesce(v_user.completed_categories, '{}');
  if not (v_challenge.category = any(v_categories)) then v_categories := array_append(v_categories, v_challenge.category); end if;
  v_next_categories := array(select distinct unnest(v_categories) order by 1);
  v_category_count := cardinality(v_next_categories);

  v_unlocked := coalesce(v_user.unlocked_achievements, '{}');
  if v_user.last_activity_date is null then
    v_current_streak := 1;
  else
    v_day_gap := v_date - v_user.last_activity_date;
    v_current_streak := case when v_day_gap = 1 then v_user.current_streak + 1 when v_day_gap = 0 then v_user.current_streak else 1 end;
  end if;
  v_longest_streak := greatest(v_user.longest_streak, v_current_streak);

  for v_achievement, v_threshold, v_reward in
    select * from (values
      ('FIRST_STEP', 1, 25), ('GETTING_STARTED', 3, 50), ('WEEK_WARRIOR', 7, 100),
      ('TWO_WEEKS', 14, 150), ('UNSTOPPABLE', 30, 300), ('CENTURY', 100, 500),
      ('EXPLORER', 5, 150), ('MASTER_EXPLORER', 8, 300)
    ) as a(id, threshold, reward)
  loop
    if v_achievement = any(v_unlocked) then continue; end if;
    v_eligible := case
      when v_achievement in ('GETTING_STARTED','WEEK_WARRIOR','TWO_WEEKS','UNSTOPPABLE') then v_current_streak >= v_threshold
      when v_achievement = 'FIRST_STEP' then v_total_activities >= v_threshold
      when v_achievement = 'CENTURY' then v_total_activities >= v_threshold
      when v_achievement in ('EXPLORER','MASTER_EXPLORER') then v_category_count >= v_threshold
      else false
    end;
    if v_eligible then
      v_unlocked := array_append(v_unlocked, v_achievement);
      v_new_achievements := array_append(v_new_achievements, v_achievement);
      v_achievement_xp := v_achievement_xp + v_reward;
      insert into public.achievements(user_id, achievement_id, unlocked_at) values (p_uid, v_achievement, now()) on conflict do nothing;
    end if;
  end loop;

  v_next_unlocked := array(select distinct unnest(v_unlocked) order by 1);
  v_total_reward := v_challenge_xp + v_achievement_xp;
  v_next_xp := v_previous_xp + v_total_reward;
  v_next_level := public.level_for_xp(v_next_xp);

  insert into public.activities(id, user_id, challenge_id, date, xp_awarded, completed_at, category)
  values (v_date::text || '-' || v_assignment.challenge_id, p_uid, v_assignment.challenge_id, v_date, v_challenge_xp, now(), v_challenge.category);

  update public.daily_challenges
  set completed = true, completed_at = now()
  where user_id = p_uid and date = v_date;

  update public.profiles
  set total_activities = v_total_activities,
      current_streak = v_current_streak,
      longest_streak = v_longest_streak,
      xp = v_next_xp,
      level = v_next_level,
      last_activity_date = v_date,
      completed_categories = v_next_categories,
      unlocked_achievements = v_next_unlocked
  where id = p_uid;

  return jsonb_build_object(
    'completed', true, 'alreadyCompleted', false, 'challengeId', v_assignment.challenge_id,
    'xpAwarded', v_total_reward, 'challengeXP', v_challenge_xp, 'achievementXP', v_achievement_xp,
    'previousXP', v_previous_xp, 'currentXP', v_next_xp,
    'previousStreak', v_previous_streak, 'currentStreak', v_current_streak,
    'longestStreak', v_longest_streak, 'previousLevel', v_previous_level,
    'newLevel', v_next_level, 'leveledUp', v_next_level > v_previous_level,
    'newAchievements', to_jsonb(v_new_achievements)
  );
end;
$$;

revoke all on function public.get_or_assign_daily_challenge(uuid) from public, anon, authenticated;
revoke all on function public.complete_challenge(uuid) from public, anon, authenticated;
grant execute on function public.get_or_assign_daily_challenge(uuid) to service_role;
grant execute on function public.complete_challenge(uuid) to service_role;
