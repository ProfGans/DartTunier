begin;
-- Preserve existing communities and caches: rankings used to be always enabled.
alter table public.communities add column ranking_enabled boolean not null default true;
grant select(ranking_enabled) on public.communities to authenticated;

create function public.update_community_settings(
  requested_community_id uuid, profile_name text, profile_bio text,
  profile_avatar text, enable_ranking boolean
) returns jsonb language plpgsql security definer set search_path = public as $$
declare result jsonb;
begin
  if enable_ranking is null then
    raise exception 'Ranglisten-Einstellung fehlt' using errcode='22023';
  end if;
  -- Existing RPC locks the community and checks edit_community before any write.
  result := public.update_community_profile(requested_community_id, profile_name, profile_bio, profile_avatar);
  update public.communities set ranking_enabled=enable_ranking where id=requested_community_id;
  return result || jsonb_build_object('ranking_enabled',enable_ranking);
end;
$$;
revoke all on function public.update_community_settings(uuid,text,text,text,boolean) from public,anon;
grant execute on function public.update_community_settings(uuid,text,text,text,boolean) to authenticated;
notify pgrst, 'reload schema';
commit;
