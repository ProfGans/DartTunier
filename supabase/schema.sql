-- Run this in the Supabase SQL Editor for project hnsyvqtqxdsbbyrayobv.
-- Never put a service role or sb_secret key into the Flutter app.

create table if not exists public.player_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  country text not null default '',
  city text not null default '',
  darts_setup_json text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  constraint player_profiles_user_id_unique unique (user_id)
);

create table if not exists public.tournaments (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_player_profiles_updated_at on public.player_profiles;
create trigger set_player_profiles_updated_at
before update on public.player_profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_tournaments_updated_at on public.tournaments;
create trigger set_tournaments_updated_at
before update on public.tournaments
for each row execute function public.set_updated_at();

alter table public.player_profiles enable row level security;
alter table public.tournaments enable row level security;

drop policy if exists "Users can read their own profile" on public.player_profiles;
create policy "Users can read their own profile"
on public.player_profiles
for select
using (auth.uid() = user_id);

drop policy if exists "Users can insert their own profile" on public.player_profiles;
create policy "Users can insert their own profile"
on public.player_profiles
for insert
with check (auth.uid() = user_id and auth.uid() = id);

drop policy if exists "Users can update their own profile" on public.player_profiles;
create policy "Users can update their own profile"
on public.player_profiles
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id and auth.uid() = id);

drop policy if exists "Users can read their own tournaments" on public.tournaments;
create policy "Users can read their own tournaments"
on public.tournaments
for select
using (auth.uid() = owner_user_id);

drop policy if exists "Users can insert their own tournaments" on public.tournaments;
create policy "Users can insert their own tournaments"
on public.tournaments
for insert
with check (auth.uid() = owner_user_id);

drop policy if exists "Users can update their own tournaments" on public.tournaments;
create policy "Users can update their own tournaments"
on public.tournaments
for update
using (auth.uid() = owner_user_id)
with check (auth.uid() = owner_user_id);
