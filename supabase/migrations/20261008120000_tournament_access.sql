begin;

create function public.tournament_access_settings(p jsonb, creator uuid)
returns jsonb language sql immutable set search_path=public as $$
 select jsonb_build_object('creatorUserId',creator::text,
   'directorUserIds',coalesce(p#>'{access,directorUserIds}','[]'::jsonb),
   'resultEntryMode',coalesce(p#>>'{access,resultEntryMode}','directors'),
   'resultUserIds',coalesce(p#>'{access,resultUserIds}','[]'::jsonb));
$$;

create function public.can_lead_tournament(c uuid, creator uuid, p jsonb)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and public.is_community_member(c) and
   (auth.uid()=creator or 'lead_tournaments'=any(public.community_permissions(c))
    or coalesce(p#>'{access,directorUserIds}','[]'::jsonb) ? auth.uid()::text);
$$;
create function public.can_report_tournament(c uuid, creator uuid, p jsonb)
returns boolean language sql stable security definer set search_path=public as $$
 select public.can_lead_tournament(c,creator,p) or
   (auth.uid() is not null and public.is_community_member(c) and
    (p#>>'{access,resultEntryMode}'='members' or
     (p#>>'{access,resultEntryMode}'='selected' and coalesce(p#>'{access,resultUserIds}','[]'::jsonb) ? auth.uid()::text)));
$$;

create function public.valid_tournament_score(m jsonb, s jsonb, f jsonb)
returns boolean language plpgsql immutable set search_path=public as $$
declare h int; a int; hs int; aws int; legs int; sets int; lw int; sw int;
begin
 if jsonb_typeof(m->'homePlayer') is distinct from 'object' or jsonb_typeof(m->'awayPlayer') is distinct from 'object'
   or coalesce((m->>'isAnnulled')::boolean,false) or nullif(m->'homeLegs','null'::jsonb) is not null
   or nullif(m->'awayLegs','null'::jsonb) is not null then return false; end if;
 if coalesce(s->>'homeLegs','') !~ '^[0-9]{1,6}$' or coalesce(s->>'awayLegs','') !~ '^[0-9]{1,6}$' then return false; end if;
 h := (s->>'homeLegs')::int; a := (s->>'awayLegs')::int;
 legs := coalesce((f->>'bestOfLegs')::int,3); sets := coalesce((f->>'bestOfSets')::int,1);
 lw := legs/2+1; sw := sets/2+1;
 if sets>1 then
   if coalesce(s->>'homeSets','') !~ '^[0-9]{1,3}$' or coalesce(s->>'awaySets','') !~ '^[0-9]{1,3}$' then return false; end if;
   hs := (s->>'homeSets')::int; aws := (s->>'awaySets')::int;
   return ((hs=sw and aws<sw) or (aws=sw and hs<sw)) and
     h between hs*lw and hs*lw+aws*(lw-1) and a between aws*lw and aws*lw+hs*(lw-1);
 end if;
 if nullif(s->'homeSets','null'::jsonb) is not null or nullif(s->'awaySets','null'::jsonb) is not null then return false; end if;
 if h=a then return legs%2=0 and h*2=legs and not coalesce((m->>'isDecider')::boolean,false); end if;
 return greatest(h,a)=lw and least(h,a)<lw and (legs%2=1 or coalesce((m->>'isDecider')::boolean,false) or h+a<=legs);
end; $$;

-- Validate the entire changed stage recursively, preserving every structural key.
create function public.tournament_result_only(old_value jsonb, new_value jsonb, format jsonb)
returns boolean language plpgsql immutable set search_path=public as $$
declare k text; i int;
begin
 if old_value is not distinct from new_value then return true; end if;
 if old_value is null or new_value is null or jsonb_typeof(old_value)<>jsonb_typeof(new_value) then return false; end if;
 if jsonb_typeof(old_value)='array' then
   if jsonb_array_length(old_value)<>jsonb_array_length(new_value) then return false; end if;
   for i in 0..jsonb_array_length(old_value)-1 loop
     if not public.tournament_result_only(old_value->i,new_value->i,format) then return false; end if;
   end loop;
   return true;
 elsif jsonb_typeof(old_value)='object' then
   if old_value ? 'homePlayer' and old_value ? 'awayPlayer' and old_value ? 'round' then
     return old_value-array['homeLegs','awayLegs','homeSets','awaySets','finishedAt'] = new_value-array['homeLegs','awayLegs','homeSets','awaySets','finishedAt']
       and public.valid_tournament_score(old_value,new_value,format);
   end if;
   if (select array_agg(key order by key) from jsonb_object_keys(old_value) as key)
      is distinct from (select array_agg(key order by key) from jsonb_object_keys(new_value) as key) then return false; end if;
   for k in select jsonb_object_keys(old_value) loop
     if not public.tournament_result_only(old_value->k,new_value->k,format) then return false; end if;
   end loop;
   return true;
 end if;
 return false;
end; $$;

create function public.league_result_only(o jsonb, n jsonb)
returns boolean language plpgsql immutable set search_path=public as $$
declare i int; a jsonb; b jsonb; h int; v int;
begin
 if o is null or n is null or o-'games' is distinct from n-'games'
   or jsonb_typeof(o->'games') is distinct from 'array' or jsonb_typeof(n->'games') is distinct from 'array'
   or jsonb_array_length(o->'games')<>jsonb_array_length(n->'games') then return false; end if;
 for i in 0..jsonb_array_length(o->'games')-1 loop
   a:=o->'games'->i; b:=n->'games'->i;
   if a is not distinct from b then continue; end if;
   if a-array['homeLegs','awayLegs','runtime'] is distinct from b-array['homeLegs','awayLegs','runtime']
     or nullif(a->'homeLegs','null'::jsonb) is not null or nullif(a->'awayLegs','null'::jsonb) is not null
     or coalesce(b->>'homeLegs','') !~ '^[0-3]$' or coalesce(b->>'awayLegs','') !~ '^[0-3]$' then return false; end if;
   h:=(b->>'homeLegs')::int; v:=(b->>'awayLegs')::int;
   if not ((h=3 and v<3) or (v=3 and h<3)) then return false; end if;
   if coalesce(a->'runtime','{}'::jsonb)-array['homeLegs','awayLegs','finishedAt']
      is distinct from coalesce(b->'runtime','{}'::jsonb)-array['homeLegs','awayLegs','finishedAt']
      or b#>'{runtime,homeLegs}' is distinct from b->'homeLegs'
      or b#>'{runtime,awayLegs}' is distinct from b->'awayLegs' then return false; end if;
 end loop;
 return true;
end; $$;

create or replace function public.enforce_community_tournament_permissions()
returns trigger language plpgsql security definer set search_path=public as $$
declare rights text[]; config_old jsonb; config_new jsonb; access_old jsonb; access_new jsonb;
  can_lead boolean; can_edit boolean; member_id text; active int; revision int;
  runtime text[] := array['updatedAt','syncRevision','access','runStages','activeStageIndex','completedStageIndexes',
    'startedAt','finishedAt','plannedMinutes','plannedMatches','plannedMatchEndSeconds','blockedBoards','allowDeviceStart','leagueMatch'];
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
  (public.can_lead_tournament(community_id,owner_user_id,payload) or public.community_permissions(community_id) && array['edit_tournaments','delete_tournaments'])))
 with check((community_id is null and owner_user_id=auth.uid()) or (community_id is not null and public.is_community_member(community_id)));

create function public.save_community_tournament_v2(tournament_payload jsonb)
returns integer language plpgsql security invoker set search_path=public as $$
declare revision int;
begin
 perform public.save_community_tournament(tournament_payload);
 select (payload->>'syncRevision')::int into revision from public.tournaments where client_tournament_id=tournament_payload->>'id';
 return revision;
end; $$;

create function public.submit_tournament_result(target_tournament text, match_path text[], expected_home jsonb,
 expected_away jsonb, expected_start text, score jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare t public.tournaments; m jsonb; active int; f jsonb; result jsonb;
begin
 if auth.uid() is null then raise exception 'Anmeldung erforderlich' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(target_tournament,0));
 select * into t from public.tournaments where client_tournament_id=target_tournament for update;
 if not found or t.is_deleted or t.community_id is null or not coalesce(public.can_report_tournament(t.community_id,t.owner_user_id,t.payload),false) then
   raise exception 'Keine Ergebnisberechtigung' using errcode='42501'; end if;
 active := coalesce((t.payload->>'activeStageIndex')::int,0);
 if coalesce(array_to_string(match_path,'/'),'') !~ '^runStages/[0-9]+/(groups/[0-9]+/(matches|placementMatches)/[0-9]+|groups/[0-9]+/knockoutRounds/[0-9]+/[0-9]+|rounds/[0-9]+/[0-9]+|placementMatches/[0-9]+)$'
   or match_path[2]<>active::text or coalesce(t.payload->'completedStageIndexes','[]'::jsonb) @> jsonb_build_array(active) then
   raise exception 'Keine offene Begegnung der aktiven Etappe'; end if;
 m := t.payload#>match_path;
 if m is null or m->'homePlayer' is distinct from expected_home or m->'awayPlayer' is distinct from expected_away
   or m->>'startedAt' is distinct from expected_start then raise exception 'Paarung wurde geändert' using errcode='40001'; end if;
 f := t.payload#>array['stages',active::text,'gameFormat'];
 if not public.valid_tournament_score(m,score,f) then raise exception 'Ungültiges oder bereits erfasstes Ergebnis'; end if;
 m := m || jsonb_build_object('homeLegs',(score->>'homeLegs')::int,'awayLegs',(score->>'awayLegs')::int,
   'homeSets',(score->>'homeSets')::int,'awaySets',(score->>'awaySets')::int,'finishedAt',to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'));
 update public.tournaments set payload=jsonb_set(t.payload,match_path,m) where id=t.id returning payload into result;
 return result;
end; $$;

create function public.submit_league_result(target_tournament text, game_index integer,
 expected_game jsonb, expected_metadata jsonb, home_score integer, away_score integer)
returns jsonb language plpgsql security definer set search_path=public as $$
declare t public.tournaments; l jsonb; g jsonb; r jsonb; result jsonb;
begin
 if auth.uid() is null then raise exception 'Anmeldung erforderlich' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(target_tournament,0));
 select * into t from public.tournaments where client_tournament_id=target_tournament for update;
 if not found or t.is_deleted or t.community_id is null or not coalesce(public.can_report_tournament(t.community_id,t.owner_user_id,t.payload),false) then
   raise exception 'Keine Ergebnisberechtigung' using errcode='42501'; end if;
 l:=t.payload->'leagueMatch';
 if l is null or l->>'preset' is distinct from 'rhl' or game_index is null or game_index<0
   or game_index>=jsonb_array_length(l->'games') then raise exception 'Ungueltiges Ligaspiel'; end if;
 g:=l->'games'->game_index;
 if g is distinct from expected_game or l-'games' is distinct from expected_metadata then
   raise exception 'Aufstellung oder Spielstand wurde geaendert' using errcode='40001'; end if;
 if nullif(g->'homeLegs','null'::jsonb) is not null or nullif(g->'awayLegs','null'::jsonb) is not null
   or home_score is null or away_score is null or home_score<0 or away_score<0
   or not ((home_score=3 and away_score<3) or (away_score=3 and home_score<3)) then
   raise exception 'Ungueltiges oder bereits erfasstes Ergebnis'; end if;
 r:=coalesce(g->'runtime','{}'::jsonb)||jsonb_build_object('homeLegs',home_score,'awayLegs',away_score,
   'finishedAt',to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'));
 g:=g||jsonb_build_object('homeLegs',home_score,'awayLegs',away_score,'runtime',r);
 update public.tournaments set payload=jsonb_set(t.payload,array['leagueMatch','games',game_index::text],g)
   where id=t.id returning payload into result;
 return result;
end; $$;
revoke all on function public.league_result_only(jsonb,jsonb), public.submit_league_result(text,integer,jsonb,jsonb,integer,integer) from public,anon;
grant execute on function public.submit_league_result(text,integer,jsonb,jsonb,integer,integer) to authenticated;

revoke all on function public.tournament_access_settings(jsonb,uuid), public.can_lead_tournament(uuid,uuid,jsonb),
 public.can_report_tournament(uuid,uuid,jsonb), public.valid_tournament_score(jsonb,jsonb,jsonb),
 public.tournament_result_only(jsonb,jsonb,jsonb), public.save_community_tournament_v2(jsonb),
 public.submit_tournament_result(text,text[],jsonb,jsonb,text,jsonb) from public,anon;
grant execute on function public.can_lead_tournament(uuid,uuid,jsonb), public.save_community_tournament_v2(jsonb),
 public.submit_tournament_result(text,text[],jsonb,jsonb,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
