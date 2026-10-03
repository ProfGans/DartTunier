begin;
alter table public.community_roles drop constraint community_roles_permissions_check;
alter table public.community_roles add constraint community_roles_permissions_check
  check (permissions <@ array['manage_roles','create_tournaments','invite_members','delete_tournaments',
    'edit_tournaments','remove_members','assign_devices','lead_tournaments','edit_community','manage_rankings','manage_highlights']::text[]);
create or replace function public.community_permissions(requested_community_id uuid)
returns text[] language sql stable security definer set search_path = public as $$
  select case
    when exists(select 1 from public.communities where id=requested_community_id and owner_user_id=auth.uid())
      then array['manage_roles','create_tournaments','invite_members','delete_tournaments',
        'edit_tournaments','remove_members','assign_devices','lead_tournaments','edit_community','manage_rankings','manage_highlights']::text[]
    else coalesce((select r.permissions from public.community_role_assignments a
      join public.community_roles r on r.id=a.role_id and r.community_id=a.community_id
      where a.community_id=requested_community_id and a.user_id=auth.uid()),'{}'::text[]) end;
$$;

-- Saved manual entries, automatic-record overrides and deletion tombstones.
create table public.community_highlights (
  community_id uuid not null references public.communities(id) on delete cascade,
  highlight_key text not null check(length(highlight_key) between 1 and 1200 and
    (highlight_key like 'manual:%' or highlight_key like 'auto:%')),
  category text not null check(category in ('average','checkout','shortLeg','maximums','other')),
  title text not null check(length(trim(title)) between 1 and 120),
  value text not null check(length(trim(value)) between 1 and 80),
  player_name text not null default '' check(length(player_name)<=512),
  tournament_name text not null default '' check(length(tournament_name)<=256),
  occurred_at timestamptz not null,
  note text not null default '' check(length(note)<=1000),
  deleted boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  updated_by uuid not null default auth.uid(),
  primary key(community_id,highlight_key)
);
alter table public.community_highlights enable row level security;
revoke all on public.community_highlights from public,anon,authenticated;
grant select,insert,update on public.community_highlights to authenticated;
create policy highlights_read on public.community_highlights for select to authenticated
  using(public.is_community_member(community_id));
create policy highlights_create on public.community_highlights for insert to authenticated
  with check(public.is_community_member(community_id) and 'manage_highlights'=any(public.community_permissions(community_id)));
create policy highlights_edit on public.community_highlights for update to authenticated
  using(public.is_community_member(community_id) and 'manage_highlights'=any(public.community_permissions(community_id)))
  with check(public.is_community_member(community_id) and 'manage_highlights'=any(public.community_permissions(community_id)));
create function public.stamp_community_highlight() returns trigger language plpgsql set search_path=public as $$
begin
  if TG_OP='UPDATE' and (new.community_id <> old.community_id or new.highlight_key <> old.highlight_key) then
    raise exception 'Highlight-Zuordnung ist unveränderlich' using errcode='22023';
  end if;
  new.updated_at=clock_timestamp(); new.updated_by=auth.uid(); return new;
end;
$$;
revoke all on function public.stamp_community_highlight() from public,anon,authenticated;
create trigger stamp_community_highlight before insert or update on public.community_highlights
  for each row execute function public.stamp_community_highlight();
notify pgrst,'reload schema';
commit;
