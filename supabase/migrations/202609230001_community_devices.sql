begin;
-- Device memberships are separate from players and never affect rankings.
create table public.community_devices (
  community_id uuid not null references public.communities(id) on delete cascade,
  owner_user_id uuid not null,
  device_id text not null,
  name text not null,
  platform text not null,
  role text not null default 'device' check (role = 'device'),
  created_at timestamptz not null default now(),
  primary key (community_id, owner_user_id, device_id),
  foreign key (owner_user_id, device_id) references public.account_devices(owner_user_id, device_id) on delete cascade
);
alter table public.community_devices enable row level security;
grant select, delete on public.community_devices to authenticated;
create policy "Read group devices" on public.community_devices for select to authenticated
  using (owner_user_id = auth.uid() or public.is_community_member(community_id));
create policy "Remove group devices" on public.community_devices for delete to authenticated
  using (owner_user_id = auth.uid() or exists (
    select 1 from public.communities c where c.id = community_id and c.owner_user_id = auth.uid()
  ));

create function public.join_community_as_device(invite_code_input text, device_id_input text)
returns void language plpgsql security definer set search_path = public as $$
declare target uuid; device public.account_devices%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into device from public.account_devices
    where owner_user_id = auth.uid() and device_id = device_id_input;
  if not found then raise exception 'Register your own device first'; end if;
  select id into target from public.communities where invite_code = upper(trim(invite_code_input));
  if target is null then raise exception 'Invalid invitation'; end if;
  insert into public.community_devices(community_id, owner_user_id, device_id, name, platform)
    values (target, auth.uid(), device.device_id, device.name, device.platform)
    on conflict (community_id, owner_user_id, device_id) do update
      set name = excluded.name, platform = excluded.platform;
end;
$$;

-- Expose only names of groups joined by the caller's devices, without granting player access.
create function public.my_device_communities(device_id_input text)
returns table(community_id uuid, community_name text)
language sql stable security definer set search_path = public as $$
  select c.id, c.name from public.communities c
  join public.community_devices d on d.community_id = c.id
  where d.owner_user_id = auth.uid() and d.device_id = device_id_input
  order by c.name;
$$;
revoke all on function public.join_community_as_device(text,text) from public, anon;
revoke all on function public.my_device_communities(text) from public, anon;
grant execute on function public.join_community_as_device(text,text) to authenticated;
grant execute on function public.my_device_communities(text) to authenticated;
commit;
