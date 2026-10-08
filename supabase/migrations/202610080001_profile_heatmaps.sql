begin;
create table if not exists public.profile_heatmaps (
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  session_id text not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (owner_user_id, session_id),
  constraint heatmap_payload_version check (payload->>'version' = '2'),
  constraint heatmap_session_identity check (payload->>'id' = session_id)
);
alter table public.profile_heatmaps enable row level security;
create policy "Owners read heatmaps" on public.profile_heatmaps for select to authenticated using (auth.uid() = owner_user_id);
create policy "Owners insert heatmaps" on public.profile_heatmaps for insert to authenticated with check (auth.uid() = owner_user_id);
create policy "Owners update heatmaps" on public.profile_heatmaps for update to authenticated using (auth.uid() = owner_user_id) with check (auth.uid() = owner_user_id);
create policy "Owners delete heatmaps" on public.profile_heatmaps for delete to authenticated using (auth.uid() = owner_user_id);
grant select, insert, update, delete on public.profile_heatmaps to authenticated;
commit;
