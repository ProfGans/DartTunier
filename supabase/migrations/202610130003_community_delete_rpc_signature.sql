-- Ensure the RPC used by the app exists with the named PostgREST argument.
-- This migration also repairs deployments where the earlier community-delete
-- migration was recorded but the function was not present in the API schema.
begin;

create or replace function public.delete_community(requested_community_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Anmeldung erforderlich' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.communities
    where id = requested_community_id and owner_user_id = auth.uid()
  ) then
    raise exception 'Community nicht gefunden oder keine Eigentümerberechtigung'
      using errcode = '42501';
  end if;

  delete from public.tournaments
  where community_id = requested_community_id;

  delete from public.communities
  where id = requested_community_id
    and owner_user_id = auth.uid();
end;
$$;

revoke all on function public.delete_community(uuid) from public, anon;
grant execute on function public.delete_community(uuid) to authenticated;
notify pgrst, 'reload schema';

commit;
