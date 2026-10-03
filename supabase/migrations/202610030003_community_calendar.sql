begin;
create table public.community_calendar_presets (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  name text not null check(length(trim(name)) between 1 and 80),
  settings jsonb not null check(jsonb_typeof(settings)='object' and (settings->>'version') is not distinct from '1' and octet_length(settings::text)<20000),
  created_at timestamptz not null default now()
);
create unique index calendar_preset_names on public.community_calendar_presets(community_id,lower(trim(name)));
create table public.community_calendar_events (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  title text not null check(length(trim(title)) between 1 and 80),
  starts_at timestamptz not null,
  location text not null default '' check(length(location)<=200),
  notes text not null default '' check(length(notes)<=1000),
  settings jsonb not null check(jsonb_typeof(settings)='object' and (settings->>'version') is not distinct from '1' and octet_length(settings::text)<20000),
  unique(id,community_id)
);
create index calendar_events_dates on public.community_calendar_events(community_id,starts_at);
create table public.community_calendar_reminders (
  event_id uuid not null,
  community_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  minutes_before integer not null check(minutes_before in (0,15,30,60,120,1440,10080)),
  primary key(event_id,user_id),
  foreign key(event_id,community_id) references public.community_calendar_events(id,community_id) on delete cascade,
  foreign key(community_id,user_id) references public.community_members(community_id,user_id) on delete cascade
);
alter table public.community_calendar_events enable row level security;
alter table public.community_calendar_presets enable row level security;
alter table public.community_calendar_reminders enable row level security;
revoke all on public.community_calendar_events,public.community_calendar_presets,public.community_calendar_reminders from public,anon,authenticated;
grant select,insert,delete on public.community_calendar_events,public.community_calendar_presets,public.community_calendar_reminders to authenticated;
grant update(title,starts_at,location,notes,settings) on public.community_calendar_events to authenticated;
grant update(minutes_before) on public.community_calendar_reminders to authenticated;
-- PostgREST upsert includes the conflict-key columns; RLS and the FK keep ownership scoped.
grant update(event_id,community_id,user_id) on public.community_calendar_reminders to authenticated;
grant all on public.community_calendar_events,public.community_calendar_presets,public.community_calendar_reminders to service_role;
create policy calendar_read on public.community_calendar_events for select to authenticated using(public.is_community_member(community_id));
create policy calendar_create on public.community_calendar_events for insert to authenticated with check('create_tournaments'=any(public.community_permissions(community_id)));
create policy calendar_edit on public.community_calendar_events for update to authenticated using('edit_tournaments'=any(public.community_permissions(community_id))) with check('edit_tournaments'=any(public.community_permissions(community_id)));
create policy calendar_delete on public.community_calendar_events for delete to authenticated using('delete_tournaments'=any(public.community_permissions(community_id)));
create policy presets_read on public.community_calendar_presets for select to authenticated using(public.is_community_member(community_id));
create policy presets_create on public.community_calendar_presets for insert to authenticated with check('create_tournaments'=any(public.community_permissions(community_id)));
create policy presets_delete on public.community_calendar_presets for delete to authenticated using('delete_tournaments'=any(public.community_permissions(community_id)));
create policy reminders_read on public.community_calendar_reminders for select to authenticated using(user_id=auth.uid() and public.is_community_member(community_id));
create policy reminders_create on public.community_calendar_reminders for insert to authenticated with check(user_id=auth.uid() and public.is_community_member(community_id));
create policy reminders_edit on public.community_calendar_reminders for update to authenticated using(user_id=auth.uid() and public.is_community_member(community_id)) with check(user_id=auth.uid() and public.is_community_member(community_id));
create policy reminders_delete on public.community_calendar_reminders for delete to authenticated using(user_id=auth.uid());

create table public.community_calendar_deliveries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.community_calendar_events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null references public.app_push_devices(id) on delete cascade,
  starts_at timestamptz not null,
  minutes_before integer not null,
  status text not null default 'claimed' check(status in ('claimed','accepted','failed','cancelled')),
  claimed_at timestamptz not null default now(),
  unique(event_id,user_id,device_id,starts_at,minutes_before)
);
alter table public.community_calendar_deliveries enable row level security;
revoke all on public.community_calendar_deliveries from public,anon,authenticated;
grant all on public.community_calendar_deliveries to service_role;
create function public.claim_calendar_reminders() returns table(
  delivery_id uuid,event_id uuid,community_id uuid,user_id uuid,device_id uuid,
  token text,title text,location text,starts_at timestamptz,minutes_before integer
) language sql security definer set search_path='' as $$
  with due as (
    select e.id as event_id,e.community_id,r.user_id,d.id as device_id,d.token,
      e.title,e.location,e.starts_at,r.minutes_before
    from public.community_calendar_events e
    join public.community_calendar_reminders r on r.event_id=e.id
    join public.community_members m on m.community_id=e.community_id and m.user_id=r.user_id
    join public.app_push_devices d on d.owner_id=r.user_id and d.platform='android'
    where e.starts_at-make_interval(mins=>r.minutes_before)<=now()
      and e.starts_at+interval '15 minutes'>now()
      and d.updated_at>now()-interval '90 days'
      and not exists(select 1 from public.community_calendar_deliveries x
        where x.event_id=e.id and x.user_id=r.user_id and x.device_id=d.id
          and x.starts_at=e.starts_at and x.minutes_before=r.minutes_before)
    order by e.starts_at limit 50
  ), claimed as (
    insert into public.community_calendar_deliveries(event_id,user_id,device_id,starts_at,minutes_before)
      select event_id,user_id,device_id,starts_at,minutes_before from due
      on conflict do nothing returning *
  ) select c.id,d.event_id,d.community_id,d.user_id,d.device_id,d.token,d.title,d.location,d.starts_at,d.minutes_before
    from claimed c join due d on c.event_id=d.event_id and c.user_id=d.user_id and c.device_id=d.device_id;
$$;
revoke all on function public.claim_calendar_reminders() from public,anon,authenticated;
grant execute on function public.claim_calendar_reminders() to service_role;
notify pgrst,'reload schema';
-- Scoped scheduler credential, never exposed to app users or returned by an RPC.
create table public.community_calendar_worker_config (
  singleton boolean primary key default true check(singleton),
  token text not null default (gen_random_uuid()::text || gen_random_uuid()::text)
);
alter table public.community_calendar_worker_config enable row level security;
revoke all on public.community_calendar_worker_config from public,anon,authenticated;
insert into public.community_calendar_worker_config(singleton) values(true);
create function public.calendar_worker_authorized(p_token text) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.community_calendar_worker_config where token=p_token);
$$;
revoke all on function public.calendar_worker_authorized(text) from public,anon,authenticated;
grant execute on function public.calendar_worker_authorized(text) to service_role;
commit;
