begin;
alter table public.communities add column if not exists avatar_base64 text
  check (avatar_base64 is null or length(avatar_base64) <= 131072);
grant select(avatar_base64) on public.communities to authenticated;
-- Existing owner-only UPDATE policy also protects this new profile field.
notify pgrst, 'reload schema';
commit;
