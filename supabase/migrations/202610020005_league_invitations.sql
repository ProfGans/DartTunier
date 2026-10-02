begin;
create table public.league_invitations (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  match_id text not null,
  title text not null,
  team integer not null check(team in (0,1)),
  slot integer not null check(slot between 0 and 8),
  display_name text not null,
  status text not null default 'pending' check(status in ('pending','accepted','declined','cancelled')),
  closed boolean not null default false,
  expires_at timestamptz not null default now() + interval '2 days',
  unique(host_id,match_id,team,slot)
);
create index league_invitation_inbox on public.league_invitations(user_id,status);
alter table public.league_invitations enable row level security;
revoke all on public.league_invitations from anon, authenticated;
create function public.league_invitation_action(action text, args jsonb default '{}')
returns jsonb language plpgsql security definer set search_path=public as $$
declare me uuid := auth.uid(); item public.league_invitations; target uuid; display text;
begin
  if me is null then raise exception 'Anmeldung erforderlich' using errcode='42501'; end if;
  if action='invite' then
    perform 1 from auth.users where id=me for update;
    target := (args->>'user')::uuid;
    if target=me or not exists(select 1 from public.community_members a join public.community_members b on a.community_id=b.community_id where a.user_id=me and b.user_id=target) then
      raise exception 'Keine gemeinsame Community' using errcode='42501';
    end if;
    if length(args->>'title') not between 1 and 200 or length(args->>'match') not between 1 and 100 then raise exception 'Ungültiges Ligaspiel'; end if;
    if exists(select 1 from public.league_invitations where host_id=me and match_id=args->>'match' and (closed or (user_id=target and status in ('pending','accepted')))) then raise exception 'Ligaspiel geschlossen oder Mitglied bereits eingeladen'; end if;
    select coalesce(nullif(display_name,''),'Mitglied') into display from public.player_profiles where id=target;
    insert into public.league_invitations(host_id,user_id,match_id,title,team,slot,display_name)
      values(me,target,args->>'match',args->>'title',(args->>'team')::int,(args->>'slot')::int,coalesce(display,'Mitglied'))
      on conflict(host_id,match_id,team,slot) do update set id=gen_random_uuid(),user_id=excluded.user_id, title=excluded.title, display_name=excluded.display_name,status='pending',expires_at=now()+interval '2 days'
      returning * into item;
    return to_jsonb(item);
  elsif action='inbox' then
    return coalesce((select jsonb_agg(to_jsonb(i)) from public.league_invitations i where user_id=me and status='pending' and not closed and expires_at>now()),'[]'::jsonb);
  elsif action='status' then
    return coalesce((select jsonb_agg(to_jsonb(i)) from public.league_invitations i where host_id=me and match_id=args->>'match'),'[]'::jsonb);
  elsif action='respond' then
    select * into item from public.league_invitations where id=(args->>'id')::uuid and user_id=me for update;
    if item.id is null or item.closed or item.expires_at<=now() or item.status<>'pending' then raise exception 'Einladung nicht mehr verfügbar'; end if;
    update public.league_invitations set status=case when (args->>'accept')::boolean then 'accepted' else 'declined' end where id=item.id;
  elsif action='cancel' then
    update public.league_invitations set status='cancelled' where id=(args->>'id')::uuid and host_id=me and not closed;
  elsif action='close' then
    perform 1 from auth.users where id=me for update;
    perform 1 from public.league_invitations where host_id=me and match_id=args->>'match' for update;
    if exists(select 1 from public.league_invitations where host_id=me and match_id=args->>'match' and status='pending') then raise exception 'Offene Einladungen zuerst beantworten oder zurückziehen'; end if;
    update public.league_invitations set closed=true where host_id=me and match_id=args->>'match';
  else raise exception 'Unbekannte Aktion';
  end if;
  return '{}'::jsonb;
end $$;
revoke all on function public.league_invitation_action(text,jsonb) from public,anon;
grant execute on function public.league_invitation_action(text,jsonb) to authenticated;
commit;
