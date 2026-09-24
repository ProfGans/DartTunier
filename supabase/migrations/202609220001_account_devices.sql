begin;
create table if not exists public.account_devices (
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (device_id ~ '^[a-f0-9]{32}$'),
  name text not null check (length(trim(name)) between 1 and 80),
  platform text not null check (length(platform) between 1 and 32),
  role text not null default 'match_display' check (role = 'match_display'),
  created_at timestamptz not null default now(),
  primary key (owner_user_id, device_id)
);
alter table public.account_devices enable row level security;
grant select, insert, update, delete on public.account_devices to authenticated;
drop policy if exists "Accounts manage their devices" on public.account_devices;
create policy "Accounts manage their devices" on public.account_devices
  for all to authenticated using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());
commit;
