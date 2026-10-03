begin;
alter table public.community_roles drop constraint community_roles_permissions_check;
alter table public.community_roles add constraint community_roles_permissions_check
  check (permissions <@ array['manage_roles','create_tournaments','invite_members','delete_tournaments',
    'edit_tournaments','remove_members','assign_devices','lead_tournaments','edit_community','manage_rankings']::text[]);

create or replace function public.community_permissions(requested_community_id uuid)
returns text[] language sql stable security definer set search_path = public as $$
  select case
    when exists(select 1 from public.communities where id=requested_community_id and owner_user_id=auth.uid())
      then array['manage_roles','create_tournaments','invite_members','delete_tournaments',
        'edit_tournaments','remove_members','assign_devices','lead_tournaments','edit_community','manage_rankings']::text[]
    else coalesce((select r.permissions from public.community_role_assignments a
      join public.community_roles r on r.id=a.role_id and r.community_id=a.community_id
      where a.community_id=requested_community_id and a.user_id=auth.uid()),'{}'::text[]) end;
$$;

-- Append-only, server-timestamped events preserve repeated resets and old games.
create table public.community_ranking_actions (
  id bigint generated always as identity primary key,
  community_id uuid not null references public.communities(id) on delete cascade,
  ranking_id text not null,
  player_key text not null,
  action text not null check(action in ('remove','reset')),
  created_at timestamptz not null default clock_timestamp(),
  created_by uuid not null
);
create index community_ranking_actions_lookup on public.community_ranking_actions(community_id,id);
alter table public.community_ranking_actions enable row level security;
revoke all on public.community_ranking_actions from public,anon,authenticated;
grant select on public.community_ranking_actions to authenticated;
create policy ranking_actions_read on public.community_ranking_actions for select to authenticated
  using(public.is_community_member(community_id));

create function public.manage_ranking_player(requested_community_id uuid,
  requested_ranking_id text, requested_player_key text, requested_action text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare result jsonb; canonical text;
begin
  perform 1 from public.communities where id=requested_community_id for update;
  if not public.is_community_member(requested_community_id) or
      not ('manage_rankings'=any(public.community_permissions(requested_community_id))) then
    raise exception 'Keine Berechtigung: Ranglisten verwalten' using errcode='42501';
  end if;
  if requested_action is null or requested_action not in ('remove','reset') then
    raise exception 'Ungültige Aktion' using errcode='22023';
  end if;
  if requested_ranking_id is null or (requested_ranking_id <> 'default' and not exists(
    select 1 from public.community_rankings where community_id=requested_community_id
      and id::text=requested_ranking_id)) then
    raise exception 'Rangliste gehört nicht zur Community' using errcode='22023';
  end if;
  select p.id::text into canonical from public.community_members m
    join public.player_profiles p on p.id=m.user_id
    where m.community_id=requested_community_id and p.id::text=requested_player_key;
  if canonical is null then
    select coalesce(g.linked_user_id::text,g.id::text) into canonical
      from public.community_guest_members g where g.community_id=requested_community_id
        and g.id::text=requested_player_key;
  end if;
  if canonical is null then raise exception 'Spieler gehört nicht zur Community' using errcode='22023'; end if;
  insert into public.community_ranking_actions(community_id,ranking_id,player_key,action,created_by)
    values(requested_community_id,requested_ranking_id,canonical,requested_action,auth.uid())
    returning to_jsonb(community_ranking_actions.*) into result;
  return result;
end;
$$;
revoke all on function public.manage_ranking_player(uuid,text,text,text) from public,anon;
grant execute on function public.manage_ranking_player(uuid,text,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
