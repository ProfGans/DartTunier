create table public.tournament_invitations (
 id uuid primary key default gen_random_uuid(),
 owner_user_id uuid not null references auth.users(id) on delete cascade,
 tournament_id text not null check(length(tournament_id) between 1 and 200),
 community_id uuid references public.communities(id) on delete cascade,
 title text not null check(length(title) between 1 and 150),
 active boolean not null default true,
 expires_at timestamptz not null default now()+interval '30 days',
 unique(owner_user_id,tournament_id)
);
create table public.tournament_join_requests (
 id uuid primary key,
 invitation_id uuid not null references public.tournament_invitations(id) on delete cascade,
 user_id uuid references auth.users(id) on delete set null,
 display_name text not null check(length(trim(display_name)) between 1 and 80),
 created_at timestamptz not null default now(),
 status text not null default 'pending' check(status in ('pending','accepted','rejected')),
 player_key text
);
create unique index tournament_join_account on public.tournament_join_requests(invitation_id,user_id) where user_id is not null;
alter table public.tournament_invitations enable row level security;
alter table public.tournament_join_requests enable row level security;

create function public.can_manage_tournament_invitation(i public.tournament_invitations)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and case when i.community_id is null then i.owner_user_id=auth.uid()
 else exists(select 1 from public.tournaments t where t.client_tournament_id=i.tournament_id
   and t.community_id=i.community_id and not t.is_deleted
   and public.can_lead_tournament(t.community_id,t.owner_user_id,t.payload)) end;
$$;
create policy invitation_director_read on public.tournament_invitations for select to authenticated
 using(public.can_manage_tournament_invitation(tournament_invitations));
create policy registration_director_read on public.tournament_join_requests for select to authenticated
 using(exists(select 1 from public.tournament_invitations i where i.id=invitation_id and public.can_manage_tournament_invitation(i)));
grant select on public.tournament_invitations,public.tournament_join_requests to authenticated;

create function public.create_tournament_invitation(target_id text, tournament_title text, target_community uuid default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare result uuid;
begin
 if auth.uid() is null then raise exception 'Anmeldung erforderlich' using errcode='42501'; end if;
 if target_community is not null and not exists(select 1 from public.tournaments t
   where t.client_tournament_id=target_id and t.community_id=target_community and not t.is_deleted
   and public.can_lead_tournament(t.community_id,t.owner_user_id,t.payload))
 then raise exception 'Keine Turnierleitungsberechtigung' using errcode='42501'; end if;
 insert into public.tournament_invitations(owner_user_id,tournament_id,community_id,title)
 values(auth.uid(),target_id,target_community,trim(tournament_title))
 on conflict(owner_user_id,tournament_id) do update set title=excluded.title, active=true, expires_at=now()+interval '30 days'
 returning id into result;
 return result;
end; $$;

create function public.tournament_invitation_info(invitation_token uuid)
returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('title',title,'community',community_id is not null)
 from public.tournament_invitations where id=invitation_token and active and expires_at>now();
$$;

create function public.request_tournament_join(invitation_token uuid, player_name text, request_key uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare i public.tournament_invitations; result uuid; account_name text;
begin
 select * into i from public.tournament_invitations where id=invitation_token for update;
 if not found or not i.active or i.expires_at<=now() then raise exception 'Einladung abgelaufen'; end if;
 if exists(select 1 from public.tournament_join_requests where id=request_key and invitation_id=i.id) then return request_key; end if;
 if auth.uid() is not null then
   select display_name into account_name from public.player_profiles where id=auth.uid();
   if coalesce(length(trim(account_name)),0)=0 then raise exception 'Account-Profil fehlt'; end if;
   player_name := account_name;
   select id into result from public.tournament_join_requests where invitation_id=i.id and user_id=auth.uid();
   if found then return result; end if;
 end if;
 if (select count(*) from public.tournament_join_requests where invitation_id=i.id)>499 then raise exception 'Anmeldelimit erreicht'; end if;
 insert into public.tournament_join_requests(id,invitation_id,user_id,display_name)
 values(request_key,i.id,auth.uid(),trim(player_name));
 return request_key;
end; $$;

create function public.resolve_tournament_join(request_id uuid, accept boolean, target_player_key text, add_to_community boolean default false)
returns void language plpgsql security definer set search_path=public as $$
declare r public.tournament_join_requests; i public.tournament_invitations;
begin
 select * into r from public.tournament_join_requests where id=request_id for update;
 select * into i from public.tournament_invitations where id=r.invitation_id;
 if i.id is null or not public.can_manage_tournament_invitation(i) then raise exception 'Keine Berechtigung' using errcode='42501'; end if;
 if r.status<>'pending' then return; end if;
 if accept and coalesce(length(target_player_key),0)=0 then raise exception 'Spieler fehlt'; end if;
 if accept and add_to_community and i.community_id is not null then
   if not ('invite_members'=any(public.community_permissions(i.community_id))) then raise exception 'Keine Einladungsberechtigung' using errcode='42501'; end if;
   if r.user_id is not null then
     insert into public.community_members(community_id,user_id,role) values(i.community_id,r.user_id,'member') on conflict do nothing;
   else
     if exists(select 1 from public.community_guest_members where id=target_player_key::uuid and community_id<>i.community_id) then
       raise exception 'Spieler gehört zu anderer Community';
     end if;
     insert into public.community_guest_members(id,community_id,display_name) values(target_player_key::uuid,i.community_id,r.display_name) on conflict(id) do nothing;
   end if;
 end if;
 update public.tournament_join_requests set status=case when accept then 'accepted' else 'rejected' end, player_key=target_player_key where id=r.id;
end; $$;

revoke all on function public.can_manage_tournament_invitation(public.tournament_invitations) from public;
revoke all on function public.create_tournament_invitation(text,text,uuid) from public;
revoke all on function public.tournament_invitation_info(uuid) from public;
revoke all on function public.request_tournament_join(uuid,text,uuid) from public;
revoke all on function public.resolve_tournament_join(uuid,boolean,text,boolean) from public;
grant execute on function public.can_manage_tournament_invitation(public.tournament_invitations) to authenticated;
grant execute on function public.create_tournament_invitation(text,text,uuid),public.resolve_tournament_join(uuid,boolean,text,boolean) to authenticated;
grant execute on function public.tournament_invitation_info(uuid),public.request_tournament_join(uuid,text,uuid) to anon,authenticated;
