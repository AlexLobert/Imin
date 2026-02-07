-- Supabase SQL: RLS policy sprawl cleanup (availability, profiles, thread_members)
-- -----------------------------------------------------------------------------
-- Goal: reduce duplicate/permissive policies, and address "auth_rls_initplan" warnings
-- by using (select auth.uid()) in remaining policies.
--
-- Copy/paste into Supabase SQL Editor (run as postgres).
--
-- IMPORTANT:
-- - This removes `thread_members_insert_self` (a critical security issue).
-- - This restricts `availability` SELECT to *only* the current user.
--   The app should show "In Now" via RPC `get_visible_in_users()` instead.

begin;

-- ---------------------------------------------------------
-- public.availability
-- ---------------------------------------------------------

drop policy if exists "availability insert" on public.availability;
drop policy if exists availability_upsert_own on public.availability;
drop policy if exists availability_write on public.availability;
drop policy if exists "insert own availability" on public.availability;

drop policy if exists "availability read" on public.availability;
drop policy if exists availability_read on public.availability;
drop policy if exists availability_read_authenticated on public.availability;
drop policy if exists availability_read_own on public.availability;
drop policy if exists "read own availability" on public.availability;

drop policy if exists "availability update" on public.availability;
drop policy if exists availability_update on public.availability;
drop policy if exists availability_update_own on public.availability;
drop policy if exists "update own availability" on public.availability;

drop policy if exists availability_insert_own on public.availability;
drop policy if exists availability_select_own on public.availability;
drop policy if exists availability_update_own on public.availability;

create policy availability_insert_own
on public.availability
for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy availability_select_own
on public.availability
for select
to authenticated
using (user_id = (select auth.uid()));

create policy availability_update_own
on public.availability
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------
-- public.profiles
-- ---------------------------------------------------------

drop policy if exists profiles_insert_own on public.profiles;
drop policy if exists profiles_write on public.profiles;
drop policy if exists "profiles upsert" on public.profiles;

drop policy if exists "profiles read" on public.profiles;
drop policy if exists profiles_read on public.profiles;
drop policy if exists profiles_read_any_authenticated on public.profiles;
drop policy if exists profiles_read_own on public.profiles;
drop policy if exists profiles_read_thread_members on public.profiles;

drop policy if exists "profiles update" on public.profiles;
drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_update_own on public.profiles;

create policy profiles_insert_own
on public.profiles
for insert
to authenticated
with check (id = (select auth.uid()));

create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy profiles_read_authenticated
on public.profiles
for select
to authenticated
using (true);

-- Privacy: don't expose emails to other users via /rest/v1/profiles.
-- The app resolves users by handle/email via the RPC below instead.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'email'
  ) then
    execute 'revoke select (email) on table public.profiles from public';
    execute 'revoke select (email) on table public.profiles from anon';
    execute 'revoke select (email) on table public.profiles from authenticated';
  end if;
end $$;

-- Resolve a user by handle (with or without @) or by email, without returning the email.
create or replace function public.resolve_profile_id(query text)
returns uuid
language sql
security definer
set search_path = public, extensions
as $$
  with input as (
    select
      nullif(btrim(resolve_profile_id.query), '') as raw,
      lower(nullif(btrim(resolve_profile_id.query), '')) as raw_lower,
      lower(trim(leading '@' from nullif(btrim(resolve_profile_id.query), ''))) as handle_lower
  )
  select p.id
  from public.profiles p
  cross join input i
  where i.raw is not null
    and (
      (i.raw_lower is not null and lower(p.handle) = i.raw_lower)
      or (i.handle_lower is not null and lower(p.handle) = i.handle_lower)
      or (i.raw_lower is not null and lower(p.email) = i.raw_lower)
    )
  limit 1;
$$;

revoke all on function public.resolve_profile_id(text) from public;
grant execute on function public.resolve_profile_id(text) to authenticated;

-- ---------------------------------------------------------
-- public.thread_members
-- ---------------------------------------------------------
-- Security: NEVER allow users to insert themselves into arbitrary thread_ids.

drop policy if exists thread_members_insert_self on public.thread_members;
drop policy if exists "members read" on public.thread_members;
drop policy if exists thread_members_read_self on public.thread_members;

-- Make delete policy initplan-friendly.
drop policy if exists thread_members_delete_self on public.thread_members;
create policy thread_members_delete_self
on public.thread_members
for delete
to authenticated
using (user_id = (select auth.uid()));

-- Helper function used by thread membership policy (avoids RLS recursion).
create or replace function public.is_thread_member(thread_id uuid, user_id uuid)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1
    from public.thread_members tm
    where tm.thread_id = is_thread_member.thread_id
      and tm.user_id = is_thread_member.user_id
  );
$$;

revoke all on function public.is_thread_member(uuid, uuid) from public;
grant execute on function public.is_thread_member(uuid, uuid) to authenticated;

drop policy if exists thread_members_read_thread on public.thread_members;
create policy thread_members_read_thread
on public.thread_members
for select
to authenticated
using (public.is_thread_member(thread_id, (select auth.uid())));

-- Performance: Supabase flagged a duplicate index on thread_members(user_id).
-- Keep the autogenerated *_idx and drop the duplicate if present.
drop index if exists public.idx_thread_members_user;

commit;

notify pgrst, 'reload schema';
