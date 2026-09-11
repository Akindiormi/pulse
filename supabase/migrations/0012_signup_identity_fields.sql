-- Adds the identity fields collected on the signup screen. Kept separate
-- from display_name (which stays as the app-wide "what to call this
-- person" field, already read by Today/Profile/Splash) so nothing that
-- already reads display_name needs to change.
alter table public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists date_of_birth date,
  add column if not exists phone_number text;

comment on column public.profiles.first_name is 'Collected at signup. Also copied into display_name at creation time for backward-compat with existing greeting/profile reads.';
comment on column public.profiles.date_of_birth is 'Collected at signup. Not used for age-gating yet; stored for future personalization.';
