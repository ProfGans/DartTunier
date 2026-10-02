begin;
create table public.community_roles (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  name text not null check(length(trim(name)) between 1 and 80),
  permissions text[] not null default '{}',
  unique(community_id,id), unique(community_id,name),
  check (permissions <@ array['manage_roles','create_tournaments','invite_members','delete_tournaments',
    'edit_tournaments','remove_members','assign_devices','lead_tournaments']::text[])
);
create table public.community_role_assignments (
  community_id uuid not null,
  user_id uuid not null,
  role_id uuid not null,
  primary key(community_id,user_id),
  foreign key(community_id,user_id) references public.community_members(community_id,user_id) on delete cascade,
  foreign key(community_id,role_id) references public.community_roles(community_id,id) on delete cascade
);
alter table public.community_roles enable row level security;
alter table public.community_role_assignments enable row level security;

create function public.community_permissions(requested_community_id uuid)
returns text[] language sql stable security definer set search_path = public as $$
  select case
    when exists(select 1 from public.communities where id=requested_community_id and owner_user_id=auth.uid())
      then array['manage_roles','create_tournaments','invite_members','delete_tournaments',
        'edit_tournaments','remove_members','assign_devices','lead_tournaments']::text[]
    else coalesce((select r.permissions from public.community_role_assignments a
      join public.community_roles r on r.id=a.role_id and r.community_id=a.community_id
      where a.community_id=requested_community_id and a.user_id=auth.uid()),'{}'::text[]) end;
$$;
revoke all on function public.community_permissions(uuid) from public,anon;
grant execute on function public.community_permissions(uuid) to authenticated;

-- Preserve existing administrators without trusting the legacy role column afterwards.
insert into public.community_roles(community_id,name,permissions)
select distinct community_id,'Administration',array['manage_roles','create_tournaments','invite_members','delete_tournaments',
 'edit_tournaments','remove_members','assign_devices','lead_tournaments']::text[]
from public.community_members where role='admin';
insert into public.community_role_assignments(community_id,user_id,role_id)
select m.community_id,m.user_id,r.id from public.community_members m
join public.community_roles r on r.community_id=m.community_id and r.name='Administration' where m.role='admin';

grant select,insert,update,delete on public.community_roles to authenticated;
grant select on public.community_role_assignments to authenticated;
revoke insert,update,delete on public.community_role_assignments from authenticated,anon;
create policy "Read community roles" on public.community_roles for select to authenticated
 using(public.is_community_member(community_id));
create policy "Create community roles" on public.community_roles for insert to authenticated
 with check('manage_roles'=any(public.community_permissions(community_id)) and permissions <@ public.community_permissions(community_id));
create policy "Edit community roles" on public.community_roles for update to authenticated
 using('manage_roles'=any(public.community_permissions(community_id)) and permissions <@ public.community_permissions(community_id))
 with check('manage_roles'=any(public.community_permissions(community_id)) and permissions <@ public.community_permissions(community_id));
create policy "Delete community roles" on public.community_roles for delete to authenticated
 using('manage_roles'=any(public.community_permissions(community_id)) and permissions <@ public.community_permissions(community_id));
create policy "Read role assignments" on public.community_role_assignments for select to authenticated
 using(public.is_community_member(community_id));

create function public.assign_community_role(requested_community_id uuid,target_user_id uuid,requested_role_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare granted text[]; existing text[]; requested text[];
begin
  -- Serialize membership administration within a community.
  perform 1 from public.communities where id=requested_community_id for update;
  granted := public.community_permissions(requested_community_id);
  if not ('manage_roles'=any(granted)) then raise exception 'Keine Berechtigung' using errcode='42501'; end if;
  if exists(select 1 from public.communities where id=requested_community_id and owner_user_id=target_user_id)
    then raise exception 'Inhaberrechte sind unveränderlich'; end if;
  select r.permissions into existing from public.community_role_assignments a join public.community_roles r on r.id=a.role_id
    where a.community_id=requested_community_id and a.user_id=target_user_id;
  if not (coalesce(existing,'{}') <@ granted) then raise exception 'Höhere Rolle kann nicht verändert werden'; end if;
  if requested_role_id is null then
    delete from public.community_role_assignments where community_id=requested_community_id and user_id=target_user_id;
  else
    select permissions into requested from public.community_roles where id=requested_role_id and community_id=requested_community_id for share;
    if requested is null or not (requested <@ granted) then raise exception 'Rolle nicht zulässig'; end if;
    insert into public.community_role_assignments values(requested_community_id,target_user_id,requested_role_id)
      on conflict(community_id,user_id) do update set role_id=excluded.role_id;
  end if;
end; $$;

create function public.remove_community_member(requested_community_id uuid,target_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  perform 1 from public.communities where id=requested_community_id for update;
  if not ('remove_members'=any(public.community_permissions(requested_community_id)))
    then raise exception 'Keine Berechtigung' using errcode='42501'; end if;
  if exists(select 1 from public.communities where id=requested_community_id and owner_user_id=target_user_id)
    then raise exception 'Der Inhaber kann nicht entfernt werden'; end if;
  update public.community_guest_members set linked_user_id=null where community_id=requested_community_id and linked_user_id=target_user_id;
  delete from public.community_role_assignments where community_id=requested_community_id and user_id=target_user_id;
  delete from public.community_devices where community_id=requested_community_id and owner_user_id=target_user_id;
  delete from public.community_members where community_id=requested_community_id and user_id=target_user_id;
end; $$;
revoke all on function public.assign_community_role(uuid,uuid,uuid) from public,anon;
revoke all on function public.remove_community_member(uuid,uuid) from public,anon;
grant execute on function public.assign_community_role(uuid,uuid,uuid) to authenticated;
grant execute on function public.remove_community_member(uuid,uuid) to authenticated;

-- A readable community record must not leak the invitation to read-only members.
revoke select on public.communities from authenticated,anon,public;
grant select(id,owner_user_id,name,description,created_at,updated_at) on public.communities to authenticated;
-- Existing codes may already be cached by members who no longer may invite.
update public.communities set invite_code=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
create function public.community_invitation(requested_community_id uuid)
returns text language plpgsql security definer set search_path=public as $$
begin
  if not ('invite_members'=any(public.community_permissions(requested_community_id)))
    then raise exception 'Keine Einladungsberechtigung' using errcode='42501'; end if;
  return (select invite_code from public.communities where id=requested_community_id);
end; $$;
revoke all on function public.community_invitation(uuid) from public,anon;
grant execute on function public.community_invitation(uuid) to authenticated;
create or replace function public.join_community_by_code(requested_code text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare selected_community public.communities;
begin
  if auth.uid() is null then raise exception 'Anmeldung erforderlich'; end if;
  select * into selected_community from public.communities where invite_code=upper(trim(requested_code));
  if selected_community.id is null then raise exception 'Einladungscode nicht gefunden'; end if;
  insert into public.community_members(community_id,user_id,role) values(selected_community.id,auth.uid(),'member')
    on conflict(community_id,user_id) do nothing;
  return to_jsonb(selected_community)-'invite_code';
end; $$;

-- Check changed fields, not merely which client screen submitted the request.
drop policy if exists "Users can read their own tournaments" on public.tournaments;
create policy "Users can read their own tournaments" on public.tournaments for select to authenticated
 using ((community_id is null and owner_user_id=auth.uid()) or
   (community_id is not null and public.is_community_member(community_id)));
create function public.enforce_community_tournament_permissions()
returns trigger language plpgsql security definer set search_path=public as $$
declare rights text[]; config_old jsonb; config_new jsonb;
begin
  if auth.uid() is null then raise exception 'Anmeldung erforderlich' using errcode='42501'; end if;
  if tg_op='UPDATE' and (new.owner_user_id<>old.owner_user_id or new.community_id is distinct from old.community_id
      or new.client_tournament_id is distinct from old.client_tournament_id) then
    raise exception 'Turnierzuordnung ist unveränderlich' using errcode='42501';
  end if;
  if new.community_id is null then return new; end if;
  rights := public.community_permissions(new.community_id);
  if tg_op='INSERT' then
    if not ('create_tournaments'=any(rights)) then raise exception 'Keine Erstellberechtigung' using errcode='42501'; end if;
  else
    if new.is_deleted is distinct from old.is_deleted and not ('delete_tournaments'=any(rights))
      then raise exception 'Keine Löschberechtigung' using errcode='42501'; end if;
    config_old := old.payload - array['updatedAt','runStages','activeStageIndex','completedStageIndexes'];
    config_new := new.payload - array['updatedAt','runStages','activeStageIndex','completedStageIndexes'];
    if (config_old is distinct from config_new or old.name<>new.name) and not ('edit_tournaments'=any(rights))
      then raise exception 'Keine Bearbeitungsberechtigung' using errcode='42501'; end if;
    if (old.payload->'runStages' is distinct from new.payload->'runStages'
      or old.payload->'activeStageIndex' is distinct from new.payload->'activeStageIndex'
      or old.payload->'completedStageIndexes' is distinct from new.payload->'completedStageIndexes')
      and not ('lead_tournaments'=any(rights))
      then raise exception 'Keine Turnierleitungsberechtigung' using errcode='42501'; end if;
  end if;
  if new.payload->>'communityId' is distinct from new.community_id::text
    or new.payload->>'id' is distinct from new.client_tournament_id then raise exception 'Ungültige Turnieridentität'; end if;
  return new;
end; $$;
create trigger enforce_community_tournament_permissions before insert or update on public.tournaments
 for each row execute function public.enforce_community_tournament_permissions();
drop policy if exists "Users can insert their own tournaments" on public.tournaments;
drop policy if exists "Users can update their own tournaments" on public.tournaments;
create policy "Authorized tournament creation" on public.tournaments for insert to authenticated
 with check(owner_user_id=auth.uid() and (community_id is null or 'create_tournaments'=any(public.community_permissions(community_id))));
create policy "Authorized tournament update" on public.tournaments for update to authenticated
 using((community_id is null and owner_user_id=auth.uid()) or (community_id is not null and
   public.community_permissions(community_id) && array['edit_tournaments','lead_tournaments','delete_tournaments']))
 with check((community_id is null and owner_user_id=auth.uid()) or (community_id is not null and
   public.community_permissions(community_id) && array['edit_tournaments','lead_tournaments','delete_tournaments']));

-- Atomic synchronization preserves the original creator when another leader saves.
create function public.save_community_tournament(tournament_payload jsonb)
returns void language plpgsql security invoker set search_path=public as $$
declare existing public.tournaments; target text;
begin
  target := tournament_payload->>'id';
  if auth.uid() is null or target is null then raise exception 'Ungültige Anfrage'; end if;
  perform pg_advisory_xact_lock(hashtextextended(target,0));
  select * into existing from public.tournaments where client_tournament_id=target for update;
  if found then
    if existing.is_deleted then raise exception 'Turnier wurde gelöscht'; end if;
    update public.tournaments set payload=tournament_payload,name=tournament_payload->>'name'
      where id=existing.id;
    if not found then raise exception 'Keine Schreibberechtigung' using errcode='42501'; end if;
  else
    insert into public.tournaments(owner_user_id,community_id,client_tournament_id,name,payload)
      values(auth.uid(),(tournament_payload->>'communityId')::uuid,target,tournament_payload->>'name',tournament_payload);
  end if;
end; $$;
revoke all on function public.save_community_tournament(jsonb) from public,anon;
grant execute on function public.save_community_tournament(jsonb) to authenticated;
-- Also permits deleting an unsynchronized local draft, after an online rights check.
create function public.delete_community_tournament(target_community uuid, target_tournament text)
returns void language plpgsql security invoker set search_path=public as $$
begin
  if not ('delete_tournaments'=any(public.community_permissions(target_community))) then
    raise exception 'Keine Löschberechtigung' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(target_tournament,0));
  update public.tournaments set is_deleted=true
    where community_id=target_community and client_tournament_id=target_tournament;
end; $$;
revoke all on function public.delete_community_tournament(uuid,text) from public,anon;
grant execute on function public.delete_community_tournament(uuid,text) to authenticated;
notify pgrst,'reload schema';
grant delete on public.community_guest_members to authenticated;
create policy "Remove manual members" on public.community_guest_members for delete to authenticated
 using('remove_members'=any(public.community_permissions(community_id)));
commit;
