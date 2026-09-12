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
  community_id uuid,
  client_tournament_id text,
  name text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  description text not null default '',
  invite_code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_members (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references public.player_profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

alter table public.tournaments
  add column if not exists community_id uuid references public.communities(id) on delete set null;
alter table public.tournaments
  add column if not exists client_tournament_id text;
create unique index if not exists tournaments_client_tournament_id_key
  on public.tournaments(client_tournament_id);
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'tournaments_community_id_fkey'
  ) then
    alter table public.tournaments
      add constraint tournaments_community_id_fkey
      foreign key (community_id) references public.communities(id) on delete set null;
  end if;
end;
$$;

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

drop trigger if exists set_communities_updated_at on public.communities;
create trigger set_communities_updated_at
before update on public.communities
for each row execute function public.set_updated_at();

alter table public.player_profiles enable row level security;
alter table public.tournaments enable row level security;
alter table public.communities enable row level security;
alter table public.community_members enable row level security;

create or replace function public.is_community_member(requested_community_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.community_members
    where community_id = requested_community_id and user_id = auth.uid()
  );
$$;

drop policy if exists "Users can read their own profile" on public.player_profiles;
create policy "Users can read their own profile"
on public.player_profiles
for select
using (auth.uid() = user_id);
-- Community members need names for the shared member list.
drop policy if exists "Community members can read member profiles" on public.player_profiles;
create policy "Community members can read member profiles"
on public.player_profiles for select
using (
  exists (
    select 1 from public.community_members mine
    join public.community_members theirs
      on theirs.community_id = mine.community_id
    where mine.user_id = auth.uid() and theirs.user_id = player_profiles.id
  )
);

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
using (
  auth.uid() = owner_user_id
  or (community_id is not null and public.is_community_member(community_id))
);

drop policy if exists "Users can insert their own tournaments" on public.tournaments;
create policy "Users can insert their own tournaments"
on public.tournaments
for insert
with check (
  auth.uid() = owner_user_id
  and (community_id is null or public.is_community_member(community_id))
);

drop policy if exists "Users can update their own tournaments" on public.tournaments;
create policy "Users can update their own tournaments"
on public.tournaments
for update
using (auth.uid() = owner_user_id)
with check (
  auth.uid() = owner_user_id
  and (community_id is null or public.is_community_member(community_id))
);

drop policy if exists "Members can read communities" on public.communities;
create policy "Members can read communities"
on public.communities for select
using (public.is_community_member(id) or auth.uid() = owner_user_id);

drop policy if exists "Users can create communities" on public.communities;
create policy "Users can create communities"
on public.communities for insert
with check (auth.uid() = owner_user_id);

drop policy if exists "Owners can update communities" on public.communities;
create policy "Owners can update communities"
on public.communities for update
using (auth.uid() = owner_user_id)
with check (auth.uid() = owner_user_id);

drop policy if exists "Members can read memberships" on public.community_members;
create policy "Members can read memberships"
on public.community_members for select
using (public.is_community_member(community_id));

drop policy if exists "Owners can add initial membership" on public.community_members;
create policy "Owners can add initial membership"
on public.community_members for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1 from public.communities
    where id = community_id and owner_user_id = auth.uid()
  )
);

create or replace function public.join_community_by_code(requested_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_community public.communities;
begin
  if auth.uid() is null then
    raise exception 'Anmeldung erforderlich';
  end if;

  select * into selected_community
  from public.communities
  where invite_code = upper(trim(requested_code));

  if selected_community.id is null then
    raise exception 'Einladungscode nicht gefunden';
  end if;

  insert into public.community_members (community_id, user_id, role)
  values (selected_community.id, auth.uid(), 'member')
  on conflict (community_id, user_id) do nothing;

  return to_jsonb(selected_community);
end;
$$;

revoke all on function public.join_community_by_code(text) from public;
grant execute on function public.join_community_by_code(text) to authenticated;
