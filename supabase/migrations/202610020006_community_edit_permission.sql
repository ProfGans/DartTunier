begin;
alter table public.community_roles drop constraint community_roles_permissions_check;
alter table public.community_roles add constraint community_roles_permissions_check
  check (permissions <@ array['manage_roles','create_tournaments','invite_members','delete_tournaments',
    'edit_tournaments','remove_members','assign_devices','lead_tournaments','edit_community']::text[]);

create or replace function public.community_permissions(requested_community_id uuid)
returns text[] language sql stable security definer set search_path = public as $$
  select case
    when exists(select 1 from public.communities where id=requested_community_id and owner_user_id=auth.uid())
      then array['manage_roles','create_tournaments','invite_members','delete_tournaments',
        'edit_tournaments','remove_members','assign_devices','lead_tournaments','edit_community']::text[]
    else coalesce((select r.permissions from public.community_role_assignments a
      join public.community_roles r on r.id=a.role_id and r.community_id=a.community_id
      where a.community_id=requested_community_id and a.user_id=auth.uid()),'{}'::text[]) end;
$$;

-- Delegated editors may only update profile fields, never ownership or invites.
create function public.update_community_profile(
  requested_community_id uuid, profile_name text, profile_bio text, profile_avatar text
) returns jsonb language plpgsql security definer set search_path = public as $$
declare result jsonb;
begin
  perform 1 from public.communities where id=requested_community_id for update;
  if not ('edit_community'=any(public.community_permissions(requested_community_id))) then
    raise exception 'Keine Berechtigung: Community bearbeiten' using errcode='42501';
  end if;
  if profile_name is null or length(trim(profile_name)) not between 1 and 80
    or profile_bio is null or length(trim(profile_bio)) > 1000
    or length(profile_avatar) > 131072 then
    raise exception 'Ungültiges Community-Profil' using errcode='22023';
  end if;
  update public.communities set name=trim(profile_name),description=trim(profile_bio),avatar_base64=profile_avatar
    where id=requested_community_id;
  select jsonb_build_object('id',id,'owner_user_id',owner_user_id,'name',name,
    'description',description,'avatar_base64',avatar_base64,'created_at',created_at,'updated_at',updated_at)
    into result from public.communities where id=requested_community_id;
  return result;
end;
$$;
revoke all on function public.update_community_profile(uuid,text,text,text) from public,anon;
grant execute on function public.update_community_profile(uuid,text,text,text) to authenticated;
notify pgrst, 'reload schema';
commit;
