begin;
create table public.community_ranking_settings (
  community_id uuid not null references public.communities(id) on delete cascade,
  ranking_id text not null,
  validity_months integer check (validity_months between 1 and 120),
  deleted boolean not null default false,
  primary key (community_id, ranking_id)
);
alter table public.community_ranking_settings enable row level security;
revoke all on public.community_ranking_settings from public, anon, authenticated;
grant select, insert, update on public.community_ranking_settings to authenticated;
create policy ranking_settings_read on public.community_ranking_settings for select to authenticated
  using (public.is_community_member(community_id));
create policy ranking_settings_insert on public.community_ranking_settings for insert to authenticated
  with check ('manage_rankings' = any(public.community_permissions(community_id)) and
    (ranking_id = 'default' or exists (select 1 from public.community_rankings r where r.id::text = ranking_id and r.community_id = community_ranking_settings.community_id)));
create policy ranking_settings_update on public.community_ranking_settings for update to authenticated
  using ('manage_rankings' = any(public.community_permissions(community_id)))
  with check ('manage_rankings' = any(public.community_permissions(community_id)));
notify pgrst, 'reload schema';
commit;
