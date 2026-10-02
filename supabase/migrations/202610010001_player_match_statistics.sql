-- One replaceable scorer session per authenticated account. Undo updates the
-- same session; community summaries continue to use tournaments.payload.
create table if not exists public.player_match_statistics (
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  session_id text not null,
  payload jsonb not null,
  primary key (owner_user_id, session_id),
  constraint statistics_payload_owner check (payload ? 'accountId' and payload->>'accountId' is not null and payload->>'accountId' = owner_user_id::text),
  constraint statistics_payload_session check (payload ? 'id' and payload->>'id' is not null and payload->>'id' = session_id),
  constraint statistics_payload_version check (payload ? 'schemaVersion' and payload->>'schemaVersion' is not null and payload->>'schemaVersion' = '1')
);
alter table public.player_match_statistics enable row level security;
grant select, insert, update on public.player_match_statistics to authenticated;

drop policy if exists "Read own scorer statistics" on public.player_match_statistics;
create policy "Read own scorer statistics" on public.player_match_statistics
  for select to authenticated using (auth.uid() = owner_user_id);
drop policy if exists "Insert own scorer statistics" on public.player_match_statistics;
create policy "Insert own scorer statistics" on public.player_match_statistics
  for insert to authenticated with check (auth.uid() = owner_user_id);
drop policy if exists "Update own scorer statistics" on public.player_match_statistics;
create policy "Update own scorer statistics" on public.player_match_statistics
  for update to authenticated using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);
