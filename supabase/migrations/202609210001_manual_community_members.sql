-- Apply after schema.sql. Manual players do not grant account access.
begin;
create table if not exists public.community_guest_members (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 80),
  linked_user_id uuid,
  joined_at timestamptz not null default now(),
  foreign key (community_id, linked_user_id)
    references public.community_members(community_id, user_id)
);
create index if not exists community_guest_members_community_idx
  on public.community_guest_members(community_id);
alter table public.community_guest_members enable row level security;
grant select, insert, update on public.community_guest_members to authenticated;
drop policy if exists "Members read manual members" on public.community_guest_members;
create policy "Members read manual members" on public.community_guest_members
  for select to authenticated
  using (public.is_community_member(community_id));
drop policy if exists "Owners create manual members" on public.community_guest_members;
create policy "Owners create manual members" on public.community_guest_members
  for insert to authenticated with check (exists (
    select 1 from public.communities c
    where c.id = community_id and c.owner_user_id = auth.uid()
  ));
drop policy if exists "Owners assign manual members" on public.community_guest_members;
create policy "Owners assign manual members" on public.community_guest_members
  for update to authenticated
  using (exists (select 1 from public.communities c
    where c.id = community_id and c.owner_user_id = auth.uid()))
  with check (exists (select 1 from public.communities c
    where c.id = community_id and c.owner_user_id = auth.uid()));
commit;
