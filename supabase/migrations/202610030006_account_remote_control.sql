begin;
create table if not exists public.account_remote_devices (
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (device_id ~ '^[a-f0-9]{32}$'),
  name text not null check (length(trim(name)) between 1 and 80),
  platform text not null check (length(platform) between 1 and 32),
  addresses text[] not null check (cardinality(addresses) between 1 and 32),
  session_key text not null check (session_key ~ '^[a-f0-9]{64}$'),
  primary key (owner_user_id, device_id)
);
alter table public.account_remote_devices enable row level security;
revoke all on public.account_remote_devices from public, anon;
grant select, insert, update, delete on public.account_remote_devices to authenticated;
drop policy if exists "Accounts manage remote devices" on public.account_remote_devices;
create policy "Accounts manage remote devices" on public.account_remote_devices
  for all to authenticated using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
commit;
