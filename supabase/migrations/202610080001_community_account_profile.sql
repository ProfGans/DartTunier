-- Only expose profile fields to authenticated members of the requested community.
-- Personal match history and editing permissions remain owner-only.
create or replace function public.community_account_profile(
  requested_community_id uuid, target_user_id uuid
) returns jsonb
language plpgsql stable security definer set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_community_member(requested_community_id)
    or not exists (select 1 from public.community_members
      where community_id = requested_community_id and user_id = target_user_id)
  then
    raise exception 'Community membership required' using errcode = '42501';
  end if;
  return (select jsonb_build_object(
    'version', 1, 'name', payload->'name', 'picture', payload->'picture',
    'nationality', payload->'nationality', 'song', payload->'song',
    'favoritePlayer', payload->'favoritePlayer',
    'favoriteDouble', payload->'favoriteDouble', 'dartSetup', payload->'dartSetup'
  ) from public.personal_profiles where owner_user_id = target_user_id);
end;
$$;
revoke all on function public.community_account_profile(uuid, uuid) from public;
grant execute on function public.community_account_profile(uuid, uuid) to authenticated;
