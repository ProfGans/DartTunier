begin;
-- The pre-existing ranking remains the implicit "default" ranking.
create table public.community_rankings (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  created_at timestamptz not null default now(),
  constraint community_ranking_reserved_name check (lower(trim(name)) <> 'standard-rangliste')
);
create unique index community_rankings_unique_name
  on public.community_rankings(community_id, lower(trim(name)));
alter table public.community_rankings enable row level security;
revoke all on public.community_rankings from public, anon, authenticated;
grant select, insert on public.community_rankings to authenticated;
create policy community_rankings_read on public.community_rankings for select
  to authenticated using (public.is_community_member(community_id));
create policy community_rankings_create on public.community_rankings for insert
  to authenticated with check (
    'edit_community' = any(public.community_permissions(community_id))
  );
notify pgrst, 'reload schema';
commit;
