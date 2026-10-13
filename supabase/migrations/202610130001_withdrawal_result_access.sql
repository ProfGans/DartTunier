begin;
create or replace function public.enforce_community_tournament_permissions()
returns trigger language plpgsql security definer set search_path=public as $$
declare rights text[]; config_old jsonb; config_new jsonb; access_old jsonb; access_new jsonb;
  can_lead boolean; can_edit boolean; member_id text; active int; revision int;
  runtime text[] := array['updatedAt','syncRevision','access','runStages','activeStageIndex','completedStageIndexes',
    'startedAt','finishedAt','plannedMinutes','plannedMatches','plannedMatchEndSeconds','blockedBoards','allowDeviceStart','leagueMatch','withdrawals'];
begin
 if auth.uid() is null then raise exception 'Anmeldung erforderlich' using errcode='42501'; end if;
 if tg_op='UPDATE' and (new.owner_user_id<>old.owner_user_id or new.community_id is distinct from old.community_id
     or new.client_tournament_id is distinct from old.client_tournament_id) then
   raise exception 'Turnierzuordnung ist unveränderlich' using errcode='42501'; end if;
 if new.community_id is null then return new; end if;
 if not public.is_community_member(new.community_id) then raise exception 'Keine Mitgliedschaft' using errcode='42501'; end if;
 rights := public.community_permissions(new.community_id);
 access_new := public.tournament_access_settings(new.payload,new.owner_user_id);
 if nullif(new.payload#>>'{access,creatorUserId}','') is not null and
    new.payload#>>'{access,creatorUserId}'<>new.owner_user_id::text then
   raise exception 'Ersteller ist unveränderlich' using errcode='42501'; end if;
 if tg_op='INSERT' then
   if not ('create_tournaments'=any(rights)) then raise exception 'Keine Erstellberechtigung' using errcode='42501'; end if;
   revision := 1;
 else
   revision := coalesce((old.payload->>'syncRevision')::int,0);
   if coalesce((new.payload->>'syncRevision')::int,0)<>revision then
     raise exception 'Online-Stand wurde geändert. Bitte neu laden.' using errcode='40001'; end if;
   revision := revision+1;
   access_old := public.tournament_access_settings(old.payload,old.owner_user_id);
   can_lead := public.can_lead_tournament(old.community_id,old.owner_user_id,old.payload);
   can_edit := auth.uid()=old.owner_user_id or 'edit_tournaments'=any(rights);
   if new.is_deleted is distinct from old.is_deleted and not ('delete_tournaments'=any(rights)) then
     raise exception 'Keine Löschberechtigung' using errcode='42501'; end if;
   if access_old is distinct from access_new and not can_edit then
     raise exception 'Keine Berechtigung für Turnierrechte' using errcode='42501'; end if;
   config_old := old.payload-runtime; config_new := new.payload-runtime;
   if (config_old is distinct from config_new or old.name<>new.name) and not can_edit then
     raise exception 'Keine Bearbeitungsberechtigung' using errcode='42501'; end if;
   if not can_lead and (old.payload-array['updatedAt','syncRevision','access'] is distinct from new.payload-array['updatedAt','syncRevision','access']) then
     -- Configuration editors do not gain the right to change games.
     if old.payload->'leagueMatch' is distinct from new.payload->'leagueMatch' then
       if not coalesce(public.can_report_tournament(old.community_id,old.owner_user_id,old.payload),false)
         or old.payload-array['updatedAt','syncRevision','leagueMatch'] is distinct from new.payload-array['updatedAt','syncRevision','leagueMatch']
         or not public.league_result_only(old.payload->'leagueMatch',new.payload->'leagueMatch') then
         raise exception 'Keine Liga-Ergebnisberechtigung' using errcode='42501'; end if;
     elsif old.payload->'withdrawals' is distinct from new.payload->'withdrawals' then
       if not coalesce(public.can_report_tournament(old.community_id,old.owner_user_id,old.payload),false)
         or old.payload-array['updatedAt','syncRevision','access','withdrawals'] is distinct from new.payload-array['updatedAt','syncRevision','access','withdrawals'] then
         raise exception 'Keine Berechtigung zum Droppen von Spielern' using errcode='42501'; end if;
     elsif old.payload->'runStages' is distinct from new.payload->'runStages' then
       active := coalesce((old.payload->>'activeStageIndex')::int,0);
       if not coalesce(public.can_report_tournament(old.community_id,old.owner_user_id,old.payload),false)
         or old.payload-array['updatedAt','syncRevision','access','runStages'] is distinct from new.payload-array['updatedAt','syncRevision','access','runStages']
         or coalesce(old.payload->'completedStageIndexes','[]'::jsonb) @> jsonb_build_array(active)
         or jsonb_set(old.payload->'runStages',array[active::text],'null'::jsonb) is distinct from jsonb_set(new.payload->'runStages',array[active::text],'null'::jsonb)
         or not public.tournament_result_only(old.payload#>array['runStages',active::text],new.payload#>array['runStages',active::text],old.payload#>array['stages',active::text,'gameFormat']) then
         raise exception 'Keine Turnierleitungsberechtigung' using errcode='42501'; end if;
     elsif (old.payload->'activeStageIndex' is distinct from new.payload->'activeStageIndex'
       or old.payload->'completedStageIndexes' is distinct from new.payload->'completedStageIndexes'
       or old.payload->'blockedBoards' is distinct from new.payload->'blockedBoards'
       or old.payload->'allowDeviceStart' is distinct from new.payload->'allowDeviceStart'
       or old.payload->'startedAt' is distinct from new.payload->'startedAt'
       or old.payload->'finishedAt' is distinct from new.payload->'finishedAt'
       or old.payload->'plannedMinutes' is distinct from new.payload->'plannedMinutes'
       or old.payload->'plannedMatches' is distinct from new.payload->'plannedMatches'
       or old.payload->'plannedMatchEndSeconds' is distinct from new.payload->'plannedMatchEndSeconds') then
       raise exception 'Keine Turnierleitungsberechtigung' using errcode='42501';
     end if;
   end if;
 end if;
 if jsonb_typeof(access_new->'directorUserIds')<>'array' or jsonb_typeof(access_new->'resultUserIds')<>'array'
   or access_new->>'resultEntryMode' not in ('directors','selected','members') then raise exception 'Ungültige Turnierrechte'; end if;
 -- Validate newly assigned accounts. Stale removed members confer no access.
 for member_id in select jsonb_array_elements_text((access_new->'directorUserIds')||(access_new->'resultUserIds')) loop
   if (tg_op='INSERT' or not ((access_old->'directorUserIds')||(access_old->'resultUserIds')) ? member_id)
     and not exists(select 1 from public.community_members where community_id=new.community_id and user_id::text=member_id) then
     raise exception 'Zuweisung nur an Community-Mitglieder'; end if;
 end loop;
 if new.payload->>'communityId' is distinct from new.community_id::text or new.payload->>'id' is distinct from new.client_tournament_id then
   raise exception 'Ungültige Turnieridentität'; end if;
 new.payload := jsonb_set(jsonb_set(new.payload,'{access}',access_new),'{syncRevision}',to_jsonb(revision));
 return new;
end; $$;
drop policy "Authorized tournament update" on public.tournaments;
create policy "Authorized tournament update" on public.tournaments for update to authenticated
 using((community_id is null and owner_user_id=auth.uid()) or (community_id is not null and public.is_community_member(community_id) and
  (public.can_lead_tournament(community_id,owner_user_id,payload) or public.can_report_tournament(community_id,owner_user_id,payload) or public.community_permissions(community_id) && array['edit_tournaments','delete_tournaments'])))
 with check((community_id is null and owner_user_id=auth.uid()) or (community_id is not null and public.is_community_member(community_id)));
commit;
