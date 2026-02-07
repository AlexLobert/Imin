-- Supabase SQL: Apple-approval blockers + security hardening
-- ---------------------------------------------------------
-- Copy/paste this into the Supabase SQL editor (run as postgres).
--
-- Sections:
--  1) Moderation tables: user_blocks, content_reports
--  2) Messaging hardening: prevent "join any thread" + enforce block on insert
--  3) Visibility enforcement: friends-only "Everyone" and circles-based visibility via RPC
--  4) Account deletion: delete_my_account_data() RPC used by the iOS app
--  5) Security lints: set stable search_path on key functions
--
-- Notes:
--  - These statements are written to be re-runnable (drops policies before recreating).
--  - The iOS app expects:
--      * RPC `public.get_visible_in_users()` returning rows with column `user_id`
--      * RPC `public.delete_my_account_data()` with no args
--      * Tables `public.user_blocks` and `public.content_reports`

begin;

-- ---------------------------------------------------------
-- 1) Moderation tables (Block + Report)
-- ---------------------------------------------------------

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

alter table public.user_blocks enable row level security;
grant select, insert, delete on table public.user_blocks to authenticated;

drop policy if exists user_blocks_read_own on public.user_blocks;
create policy user_blocks_read_own
on public.user_blocks
for select
to authenticated
using (blocker_id = (select auth.uid()));

drop policy if exists user_blocks_insert_own on public.user_blocks;
create policy user_blocks_insert_own
on public.user_blocks
for insert
to authenticated
with check (blocker_id = (select auth.uid()));

drop policy if exists user_blocks_delete_own on public.user_blocks;
create policy user_blocks_delete_own
on public.user_blocks
for delete
to authenticated
using (blocker_id = (select auth.uid()));

create table if not exists public.content_reports (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  thread_id uuid references public.threads(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  reported_user_id uuid references auth.users(id) on delete set null,
  reason text not null,
  details text null
);

create index if not exists idx_content_reports_created_at on public.content_reports (created_at desc);
create index if not exists idx_content_reports_reporter_id on public.content_reports (reporter_id);

alter table public.content_reports enable row level security;
grant select, insert on table public.content_reports to authenticated;

do $$
begin
  if to_regclass('public.content_reports_id_seq') is not null then
    execute 'grant usage, select on sequence public.content_reports_id_seq to authenticated';
  end if;
end $$;

drop policy if exists content_reports_insert_self on public.content_reports;
create policy content_reports_insert_self
on public.content_reports
for insert
to authenticated
with check (reporter_id = (select auth.uid()));

-- Optional: allow the reporter to see their own reports in-app (not required).
drop policy if exists content_reports_read_self on public.content_reports;
create policy content_reports_read_self
on public.content_reports
for select
to authenticated
using (reporter_id = (select auth.uid()));

-- ---------------------------------------------------------
-- 2) Messaging hardening
-- ---------------------------------------------------------
-- Critical security fix:
--  - Disallow "self-inserting" into thread_members (otherwise users can join any thread_id and read messages).
--  - Enforce that message inserts require membership AND no block relationship.
--  - Prevent creating/adding thread members when a block exists (server-side enforcement for Block).
--
-- The app creates threads via RPC `create_thread_with_member`, so direct insert into thread_members is not required.

drop policy if exists thread_members_insert_self on public.thread_members;
drop policy if exists thread_members_insert_own on public.thread_members;
drop policy if exists thread_members_write on public.thread_members;

-- Replace the previous message insert policy with one that:
--  1) sender_id = auth.uid()
--  2) sender is a member of the thread
--  3) no block exists between sender and any other participant in the thread

drop policy if exists messages_insert_sender on public.messages;
drop policy if exists messages_insert_sender_member_not_blocked on public.messages;

create policy messages_insert_sender_member_not_blocked
on public.messages
for insert
to authenticated
with check (
  (select auth.uid()) = sender_id
  and exists (
    select 1
    from public.thread_members tm
    where tm.thread_id = messages.thread_id
      and tm.user_id = (select auth.uid())
  )
  and not exists (
    select 1
    from public.thread_members tm_other
    join public.user_blocks ub
      on (ub.blocker_id = tm_other.user_id and ub.blocked_id = (select auth.uid()))
      or (ub.blocker_id = (select auth.uid()) and ub.blocked_id = tm_other.user_id)
    where tm_other.thread_id = messages.thread_id
      and tm_other.user_id <> (select auth.uid())
  )
);

-- Enforce "Block" at the database level by preventing adding blocked users to a thread.
-- This stops both:
--  - creating a new 1:1 thread with someone you blocked (or who blocked you)
--  - adding a blocked user into an existing thread

create or replace function public.thread_members_block_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  other_user uuid;
begin
  for other_user in
    select tm.user_id
    from public.thread_members tm
    where tm.thread_id = new.thread_id
  loop
    if exists (
      select 1
      from public.user_blocks ub
      where (ub.blocker_id = new.user_id and ub.blocked_id = other_user)
         or (ub.blocker_id = other_user and ub.blocked_id = new.user_id)
    ) then
      raise exception 'Cannot add blocked user to thread';
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_thread_members_block_guard on public.thread_members;
create trigger trg_thread_members_block_guard
before insert on public.thread_members
for each row
execute function public.thread_members_block_guard();

-- ---------------------------------------------------------
-- 3) Visibility enforcement (server-side)
-- ---------------------------------------------------------
-- "Everyone" means: ALL FRIENDS (accepted friend_requests), not all users.
-- "Circles" means: only users who are members of one of the selected circle_ids.
--
-- The iOS app calls this RPC to build the "In Now" list.

create or replace function public.get_visible_in_users()
returns table (user_id uuid)
language sql
security definer
set search_path = public
as $$
  with me as (
    select (select auth.uid()) as uid
  ),
  friends as (
    select
      case
        when fr.sender_id = me.uid then fr.receiver_id
        else fr.sender_id
      end as friend_id
    from public.friend_requests fr
    cross join me
    where fr.status::text = 'accepted'
      and (fr.sender_id = me.uid or fr.receiver_id = me.uid)
  ),
  in_users as (
    select
      a.user_id,
      coalesce(a.visibility_mode::text, 'everyone') as visibility_mode,
      a.visibility_circle_ids
    from public.availability a
    join friends f on f.friend_id = a.user_id
    where a.state::text = 'in'
      and (a.expires_at is null or a.expires_at > now())
  )
  select iu.user_id
  from in_users iu
  cross join me
  where iu.visibility_mode = 'everyone'
     or (
       iu.visibility_mode = 'circles'
       and iu.visibility_circle_ids is not null
       and exists (
         select 1
         from public.circle_members cm
         where cm.user_id = me.uid
           and cm.circle_id = any(iu.visibility_circle_ids)
       )
     );
$$;

revoke all on function public.get_visible_in_users() from public;
grant execute on function public.get_visible_in_users() to authenticated;

-- Optional privacy hardening: ensure availability rows are not directly readable except your own.
-- If you already have custom policies, review before running this block.
--
-- drop policy if exists availability_read on public.availability;
-- drop policy if exists availability_read_authenticated on public.availability;
-- drop policy if exists availability_read_own on public.availability;
-- drop policy if exists "availability read" on public.availability;
-- drop policy if exists "read own availability" on public.availability;
--
-- create policy availability_read_own
-- on public.availability
-- for select
-- to authenticated
-- using (user_id = (select auth.uid()));

-- ---------------------------------------------------------
-- 4) Account deletion (server-side cleanup)
-- ---------------------------------------------------------
-- Called by the iOS app (best-effort) before deleting the auth user.

create or replace function public.delete_my_account_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Safety / moderation
  if to_regclass('public.user_blocks') is not null then
    execute 'delete from public.user_blocks where blocker_id = $1 or blocked_id = $1' using uid;
  end if;
  if to_regclass('public.content_reports') is not null then
    execute 'delete from public.content_reports where reporter_id = $1 or reported_user_id = $1' using uid;
  end if;

  -- Chat
  if to_regclass('public.messages') is not null then
    execute 'delete from public.messages where sender_id = $1' using uid;
  end if;
  if to_regclass('public.thread_members') is not null then
    execute 'delete from public.thread_members where user_id = $1' using uid;
  end if;

  -- Circles
  if to_regclass('public.circle_members') is not null then
    execute 'delete from public.circle_members where user_id = $1' using uid;
  end if;
  if to_regclass('public.circles') is not null then
    execute 'delete from public.circles where owner_id = $1' using uid;
  end if;

  -- Friends
  if to_regclass('public.friend_requests') is not null then
    execute 'delete from public.friend_requests where sender_id = $1 or receiver_id = $1' using uid;
  end if;
  if to_regclass('public.friendships') is not null then
    -- Column names vary by implementation; update if needed.
    begin
      execute 'delete from public.friendships where user_id = $1 or friend_id = $1' using uid;
    exception when undefined_column then
      -- ignore; this table may not exist or uses different column names
      null;
    end;
  end if;

  -- Status
  if to_regclass('public.availability') is not null then
    execute 'delete from public.availability where user_id = $1' using uid;
  end if;

  -- Profile
  if to_regclass('public.profiles') is not null then
    execute 'delete from public.profiles where id = $1' using uid;
  end if;
end;
$$;

revoke all on function public.delete_my_account_data() from public;
grant execute on function public.delete_my_account_data() to authenticated;

-- ---------------------------------------------------------
-- 5) Security lints: set stable search_path on key functions
-- ---------------------------------------------------------
-- Fixes Supabase linter warning: Function Search Path Mutable

do $$
declare
  r record;
begin
  for r in
    select
      n.nspname as schema_name,
      p.proname as func_name,
      pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'sync_profile_email',
        'handle_new_user',
        'touch_thread_updated_at',
        'create_thread_with_member'
      )
  loop
    execute format(
      'alter function %I.%I(%s) set search_path = public, extensions;',
      r.schema_name,
      r.func_name,
      r.args
    );
  end loop;
end $$;

commit;

-- After running, you may want to refresh PostgREST's schema cache:
--   notify pgrst, 'reload schema';

-- Optional (recommended): remove any overly permissive "ALL" policy on profiles if it exists.
-- This is the Supabase linter warning: RLS Policy Always True
--   drop policy if exists "profiles upsert" on public.profiles;

-- Optional (recommended): drop the duplicate index flagged by Supabase linter (keep one).
--   drop index if exists public.idx_thread_members_user;
