-- Server-managed sender allowlist. Never grant this role from a profile name.
create table if not exists public.app_push_senders (
  user_id uuid primary key references auth.users(id) on delete cascade
);
create table if not exists public.app_push_devices (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique check (length(token) between 20 and 4096),
  name text not null check (length(trim(name)) between 1 and 80),
  platform text not null check (platform in ('android','ios','web','windows')),
  updated_at timestamptz not null default now()
);
create table if not exists public.app_push_dispatches (
  id uuid primary key,
  sender_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  result jsonb not null default '{"status":"processing"}'::jsonb
);
alter table public.app_push_senders enable row level security;
alter table public.app_push_devices enable row level security;
alter table public.app_push_dispatches enable row level security;
revoke all on public.app_push_senders, public.app_push_devices, public.app_push_dispatches from anon, authenticated;
grant all on public.app_push_senders, public.app_push_devices, public.app_push_dispatches to service_role;

create or replace function public.can_send_app_push() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists(select 1 from public.app_push_senders where user_id=auth.uid());
$$;
revoke all on function public.can_send_app_push() from public;
grant execute on function public.can_send_app_push() to authenticated;

create or replace function public.register_app_push_device(p_token text, p_name text, p_platform text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare device_id uuid;
begin
  if auth.uid() is null then raise exception 'Anmeldung erforderlich'; end if;
  insert into public.app_push_devices(owner_id,token,name,platform)
    values(auth.uid(),p_token,trim(p_name),p_platform)
    on conflict(token) do update set owner_id=excluded.owner_id,name=excluded.name,
      platform=excluded.platform,updated_at=now()
    returning id into device_id;
  return device_id;
end;
$$;
revoke all on function public.register_app_push_device(text,text,text) from public;
grant execute on function public.register_app_push_device(text,text,text) to authenticated;

create or replace function public.unregister_app_push_device(p_token text)
returns void language sql security definer set search_path = '' as $$
  delete from public.app_push_devices where token=p_token and owner_id=auth.uid();
$$;
revoke all on function public.unregister_app_push_device(text) from public;
grant execute on function public.unregister_app_push_device(text) to authenticated;

create or replace function public.list_app_push_devices()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.can_send_app_push() then raise exception 'Keine Versandberechtigung'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,
    'platform',d.platform,'owner',coalesce(p.display_name,'App-Nutzer'),'updated_at',d.updated_at)
    order by d.updated_at desc)
    from public.app_push_devices d left join public.player_profiles p on p.user_id=d.owner_id
    where d.updated_at > now() - interval '90 days'), '[]'::jsonb);
end;
$$;
revoke all on function public.list_app_push_devices() from public;
grant execute on function public.list_app_push_devices() to authenticated;
