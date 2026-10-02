begin;
-- Schema v1: authenticated, expiring lobbies. All writes go through the RPC.
create table public.scorer_lobbies (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete cascade,
  code text not null unique default upper(replace(gen_random_uuid()::text,'-','')),
  expires_at timestamptz not null default now() + interval '2 hours',
  open boolean not null default true
);
create table public.scorer_lobby_members (
  lobby_id uuid not null references public.scorer_lobbies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  joined_at timestamptz not null default now(),
  primary key(lobby_id,user_id)
);
create table public.scorer_invitations (
  id uuid primary key default gen_random_uuid(),
  lobby_id uuid not null references public.scorer_lobbies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','accepted','declined')),
  unique(lobby_id,user_id)
);
create index scorer_invitation_recipient on public.scorer_invitations(user_id,status);
create index scorer_lobby_host on public.scorer_lobbies(host_id);
alter table public.scorer_lobbies enable row level security;
alter table public.scorer_lobby_members enable row level security;
alter table public.scorer_invitations enable row level security;
revoke all on public.scorer_lobbies,public.scorer_lobby_members,public.scorer_invitations from anon,authenticated;

create function public.scorer_lobby_action(action text, args jsonb default '{}')
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  me uuid := auth.uid();
  room public.scorer_lobbies;
  invitation public.scorer_invitations;
  target uuid;
  display text;
begin
  if me is null then raise exception 'Anmeldung erforderlich' using errcode='42501'; end if;
  select coalesce(nullif(trim(p.display_name),''),'Spieler') into display from public.player_profiles p where p.id=me;
  if display is null then
    select coalesce(nullif(trim(raw_user_meta_data->>'display_name'),''),'Spieler') into display from auth.users where id=me;
  end if;
  if action='candidates' then
    return coalesce((select jsonb_agg(to_jsonb(c)) from (
      select other.user_id, coalesce(p.display_name,'Mitglied') as display_name,
        string_agg(distinct g.name, ', ' order by g.name) as groups
      from public.community_members own
      join public.community_members other on other.community_id=own.community_id and other.user_id<>me
      join public.communities g on g.id=own.community_id
      left join public.player_profiles p on p.id=other.user_id
      where own.user_id=me group by other.user_id,p.display_name order by display_name
    ) c),'[]'::jsonb);
  elsif action='invitations' then
    return coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'host_name',coalesce(p.display_name,'Spieler')))
      from public.scorer_invitations i join public.scorer_lobbies l on l.id=i.lobby_id
      left join public.player_profiles p on p.id=l.host_id
      where i.user_id=me and i.status='pending' and l.open and l.expires_at>now()),'[]'::jsonb);
  elsif action='create' then
    -- One open lobby per host, including abandoned sessions after app crashes.
    perform 1 from auth.users where id=me for update;
    update public.scorer_lobbies set open=false where host_id=me and open;
    insert into public.scorer_lobbies(host_id) values(me) returning * into room;
  elsif action='join' then
    select * into room from public.scorer_lobbies where code=upper(args->>'code') for update;
    if room.id is null or not room.open or room.expires_at<=now() then raise exception 'Einladung abgelaufen oder Spiel bereits gestartet'; end if;
    if room.host_id=me then raise exception 'Du bist bereits Gastgeber'; end if;
    insert into public.scorer_lobby_members(lobby_id,user_id,display_name) values(room.id,me,display)
      on conflict(lobby_id,user_id) do update set display_name=excluded.display_name;
    update public.scorer_invitations set status='accepted' where lobby_id=room.id and user_id=me;
    return '{}'::jsonb;
  elsif action='respond' then
    -- Lock order always room before invitation to serialize joins with start/close.
    select l.* into room from public.scorer_lobbies l join public.scorer_invitations i on i.lobby_id=l.id
      where i.id=(args->>'invitation')::uuid and i.user_id=me for update of l;
    if room.id is null or not room.open or room.expires_at<=now() then raise exception 'Einladung nicht mehr verfügbar'; end if;
    select * into invitation from public.scorer_invitations where id=(args->>'invitation')::uuid and user_id=me for update;
    if invitation.status<>'pending' then raise exception 'Einladung bereits beantwortet'; end if;
    if (args->>'accept')::boolean then
      insert into public.scorer_lobby_members(lobby_id,user_id,display_name) values(room.id,me,display)
        on conflict(lobby_id,user_id) do update set display_name=excluded.display_name;
      update public.scorer_invitations set status='accepted' where id=invitation.id;
    else
      update public.scorer_invitations set status='declined' where id=invitation.id;
    end if;
    return '{}'::jsonb;
  else
    select * into room from public.scorer_lobbies where id=(args->>'id')::uuid and host_id=me for update;
    if room.id is null then raise exception 'Keine Berechtigung' using errcode='42501'; end if;
    if action='close' then
      update public.scorer_lobbies set open=false where id=room.id returning * into room;
    elsif action='snapshot' then
      null;
    elsif action in ('invite','remove') then
      if not room.open or room.expires_at<=now() then raise exception 'Lobby geschlossen'; end if;
      target := (args->>'user_id')::uuid;
      if action='remove' then
        delete from public.scorer_lobby_members where lobby_id=room.id and user_id=target;
        update public.scorer_invitations set status='declined' where lobby_id=room.id and user_id=target;
      else
        if target=me or not exists(select 1 from public.community_members a join public.community_members b
          on a.community_id=b.community_id where a.user_id=me and b.user_id=target) then
          raise exception 'Keine gemeinsame Gruppe' using errcode='42501';
        end if;
        -- Repeated taps do not re-notify a declined invitation.
        insert into public.scorer_invitations(lobby_id,user_id) values(room.id,target) on conflict do nothing;
      end if;
      return '{}'::jsonb;
    else raise exception 'Unbekannte Aktion';
    end if;
  end if;
  return jsonb_build_object('id',room.id,'code',room.code,'expires_at',room.expires_at,'open',room.open and room.expires_at>now(),
    'members',coalesce((select jsonb_agg(jsonb_build_object('user_id',user_id,'display_name',display_name) order by joined_at,user_id)
      from public.scorer_lobby_members where lobby_id=room.id),'[]'::jsonb));
end;
$$;
revoke all on function public.scorer_lobby_action(text,jsonb) from public,anon;
grant execute on function public.scorer_lobby_action(text,jsonb) to authenticated;
commit;
