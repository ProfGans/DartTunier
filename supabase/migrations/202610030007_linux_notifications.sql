-- Linux uses a scoped device capability, never the user's refresh token.
alter table public.app_push_devices drop constraint if exists app_push_devices_platform_check;
alter table public.app_push_devices add constraint app_push_devices_platform_check
  check(platform in ('android','ios','web','windows','linux'));

create table public.linux_notification_queue (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.app_push_devices(id) on delete cascade,
  dedupe_key text not null,
  title text not null check(length(title) between 1 and 200),
  body text not null check(length(body) <= 2000),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '1 day',
  acknowledged_at timestamptz,
  calendar_event_id uuid,
  calendar_starts_at timestamptz,
  calendar_minutes integer,
  unique(device_id,dedupe_key)
);
alter table public.linux_notification_queue enable row level security;
revoke all on public.linux_notification_queue from public, anon, authenticated;
grant all on public.linux_notification_queue to service_role;
create index linux_notification_pending on public.linux_notification_queue(device_id,created_at)
  where acknowledged_at is null;

create or replace function public.register_linux_notification_device(p_secret text, p_name text)
returns uuid language plpgsql security definer set search_path='' as $$
declare device uuid; hashed text;
begin
  if auth.uid() is null or p_secret !~ '^[0-9a-f]{64}$' or p_secret is null then
    raise exception 'Invalid device registration';
  end if;
  hashed := 'linux:' || encode(sha256(convert_to(p_secret,'UTF8')),'hex');
  if exists(select 1 from public.app_push_devices where token=hashed and owner_id<>auth.uid()) then
    raise exception 'Device belongs to another user';
  end if;
  insert into public.app_push_devices(owner_id,token,name,platform)
    values(auth.uid(),hashed,trim(p_name),'linux')
    on conflict(token) do update set name=excluded.name,updated_at=now()
    returning id into device;
  return device;
end;
$$;
revoke all on function public.register_linux_notification_device(text,text) from public;
grant execute on function public.register_linux_notification_device(text,text) to authenticated;

create or replace function public.poll_linux_notifications(p_secret text, p_ack uuid[] default '{}', p_disable boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare device public.app_push_devices; result jsonb;
begin
  if p_secret is null or p_secret !~ '^[0-9a-f]{64}$' or coalesce(array_length(p_ack,1),0)>100 then
    raise exception 'Invalid capability';
  end if;
  select * into device from public.app_push_devices
    where platform='linux' and token='linux:'||encode(sha256(convert_to(p_secret,'UTF8')),'hex') for update;
  if not found then raise exception 'Device revoked'; end if;
  if p_disable then
    delete from public.app_push_devices where id=device.id;
    return '[]'::jsonb;
  end if;
  update public.app_push_devices set updated_at=now() where id=device.id;
  delete from public.linux_notification_queue where device_id=device.id and expires_at<now();
  update public.linux_notification_queue set acknowledged_at=now()
    where device_id=device.id and id=any(p_ack);
  -- Produce this device's calendar reminders without requiring Firebase.
  insert into public.linux_notification_queue(device_id,dedupe_key,title,body,expires_at,
      calendar_event_id,calendar_starts_at,calendar_minutes)
    select device.id, 'calendar:'||e.id::text||':'||e.starts_at::text||':'||r.minutes_before::text,
      left('Turniererinnerung: '||e.title,200),
      left('Beginn: '||to_char(e.starts_at at time zone 'Europe/Berlin','DD.MM.YYYY HH24:MI')||
        ' (Europe/Berlin)'||case when coalesce(e.location,'')='' then '' else ' · '||e.location end,2000),
      e.starts_at+interval '15 minutes', e.id,e.starts_at,r.minutes_before
    from public.community_calendar_reminders r
    join public.community_calendar_events e on e.id=r.event_id
    join public.community_members m on m.community_id=e.community_id and m.user_id=r.user_id
    where r.user_id=device.owner_id and e.starts_at-make_interval(mins=>r.minutes_before)<=now()
      and e.starts_at+interval '15 minutes'>now()
    on conflict(device_id,dedupe_key) do nothing;
  select coalesce(jsonb_agg(row_to_json(q)),'[]'::jsonb) into result from (
    select n.id,n.title,n.body from public.linux_notification_queue n
    where n.device_id=device.id and n.acknowledged_at is null and n.expires_at>now()
      and (n.calendar_event_id is null or exists(
        select 1 from public.community_calendar_events e
        join public.community_calendar_reminders r on r.event_id=e.id and r.user_id=device.owner_id
        join public.community_members m on m.community_id=e.community_id and m.user_id=device.owner_id
        where e.id=n.calendar_event_id and e.starts_at=n.calendar_starts_at and r.minutes_before=n.calendar_minutes))
    order by n.created_at limit 50
  ) q;
  return result;
end;
$$;
revoke all on function public.poll_linux_notifications(text,uuid[],boolean) from public;
grant execute on function public.poll_linux_notifications(text,uuid[],boolean) to anon, authenticated;

