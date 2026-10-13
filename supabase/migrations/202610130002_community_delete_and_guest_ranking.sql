begin;

alter table public.community_guest_members
  add column if not exists ranking_eligible boolean not null default true;

-- Existing Challonge imports used to create every unmatched account as a
-- normal manual member. Mark those archive-only identities as guests while
-- preserving the configured real-player roster.
update public.community_guest_members guest
set ranking_eligible = false
where lower(trim(guest.display_name)) not in (
  'markus dämgen', 'marvin stelkyte', 'steven tittel', 'timo schäfer',
  'jan wald', 'andre wilke', 'patrick kaspar', 'christian klein',
  'maximilian reusch', 'jonas bung', 'tobias beitz', 'kevin kirst',
  'michael rockenbach', 'dietmar schneider', 'daniel kühnreich',
  'timo brochhagen', 'friedel dämgen', 'burkhard henn', 'bernd rau',
  'johannes rau', 'michael lemmer', 'juan beitz', 'alexander schinko',
  'yannick lorenz'
)
and exists (
  select 1
  from public.tournaments tournament
  cross join lateral jsonb_array_elements(
    case when jsonb_typeof(tournament.payload->'players') = 'array'
      then tournament.payload->'players' else '[]'::jsonb end
  ) participant
  where tournament.community_id = guest.community_id
    and tournament.payload ? 'importedArchive'
    and participant->>'profileId' = guest.id::text
);

create or replace function public.create_import_guest_member(
  requested_community_id uuid,
  guest_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare created public.community_guest_members;
begin
  if auth.uid() is null or not (
    'create_tournaments' = any(public.community_permissions(requested_community_id))
  ) then
    raise exception 'Keine Berechtigung zum Importieren von Turnieren'
      using errcode = '42501';
  end if;
  if guest_name is null or length(trim(guest_name)) not between 1 and 80 then
    raise exception 'Ungültiger Gastspielername';
  end if;

  insert into public.community_guest_members(
    community_id, display_name, ranking_eligible
  ) values (
    requested_community_id, trim(guest_name), false
  ) returning * into created;

  return jsonb_build_object(
    'id', created.id,
    'display_name', created.display_name,
    'joined_at', created.joined_at,
    'ranking_eligible', created.ranking_eligible
  );
end;
$$;

revoke all on function public.create_import_guest_member(uuid, text)
  from public, anon;
grant execute on function public.create_import_guest_member(uuid, text)
  to authenticated;

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
