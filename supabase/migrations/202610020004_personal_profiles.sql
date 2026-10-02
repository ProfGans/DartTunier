-- Private, versioned personal profile, including its resized image.
create table if not exists public.personal_profiles (
  owner_user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  constraint personal_profile_version check (payload ? 'version' and payload->>'version' = '1'),
  constraint personal_profile_name check (jsonb_typeof(payload->'name') = 'string' and length(trim(payload->>'name')) between 1 and 100),
  constraint personal_profile_size check (octet_length(payload::text) <= 8388608)
);
alter table public.personal_profiles enable row level security;
grant select, insert, update on public.personal_profiles to authenticated;
drop policy if exists "Read own personal profile" on public.personal_profiles;
create policy "Read own personal profile" on public.personal_profiles for select to authenticated using (auth.uid() = owner_user_id);
drop policy if exists "Insert own personal profile" on public.personal_profiles;
create policy "Insert own personal profile" on public.personal_profiles for insert to authenticated with check (auth.uid() = owner_user_id);
drop policy if exists "Update own personal profile" on public.personal_profiles;
create policy "Update own personal profile" on public.personal_profiles for update to authenticated using (auth.uid() = owner_user_id) with check (auth.uid() = owner_user_id);
