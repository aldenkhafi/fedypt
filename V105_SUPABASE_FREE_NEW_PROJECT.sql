-- FITNESS JOURNEY V105
-- SUPABASE FREE - NEW PROJECT / FROM ZERO
-- Run this file FIRST in a brand-new Supabase project's SQL Editor.
-- Do NOT run V105_SESSION_MIGRATION.sql for the initial setup.
--
-- This schema is based on the tables/columns actually used by the V105
-- connected application: user_access, pt_directory, pt_clients,
-- pt_packages, pt_schedules, pt_conducts and pt_extension_requests.

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    raise exception 'Supabase authenticated role is missing';
  end if;
end $$;

-- ------------------------------------------------------------
-- USER ACCESS / GOOGLE LOGIN APPROVAL
-- ------------------------------------------------------------
create table if not exists public.user_access (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  role text not null default 'PT',
  status text not null default 'pending',
  outlet text,
  created_at timestamptz not null default now(),
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint user_access_status_chk check (lower(status) in ('pending','approved','rejected'))
);

create index if not exists user_access_status_idx on public.user_access(status);
create index if not exists user_access_email_idx on public.user_access(lower(email));

-- ------------------------------------------------------------
-- MASTER ADMIN / PT DIRECTORY
-- ------------------------------------------------------------
create table if not exists public.pt_directory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  pt_name text not null,
  email text,
  status text not null default 'active',
  outlet text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pt_directory_status_chk check (lower(status) in ('active','inactive'))
);

create index if not exists pt_directory_status_idx on public.pt_directory(status);
create index if not exists pt_directory_outlet_idx on public.pt_directory(outlet);

-- ------------------------------------------------------------
-- CLIENTS
-- ------------------------------------------------------------
create table if not exists public.pt_clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  profile jsonb not null default '{}'::jsonb,
  notes text,
  pt_user_id uuid references auth.users(id) on delete set null,
  pt_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pt_clients_pt_user_idx on public.pt_clients(pt_user_id);
create index if not exists pt_clients_name_idx on public.pt_clients(lower(name));
create index if not exists pt_clients_email_idx on public.pt_clients(lower(email));

-- ------------------------------------------------------------
-- PACKAGES / SESSION BALANCE
-- ------------------------------------------------------------
create table if not exists public.pt_packages (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.pt_clients(id) on delete cascade,
  package_name text not null,
  total_sessions integer not null default 0,
  used_sessions integer not null default 0,
  scheduled_sessions integer not null default 0,
  purchase_date date,
  expiry_date date,
  price numeric(14,2) not null default 0,
  status text not null default 'ACTIVE',
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pt_packages_total_chk check (total_sessions >= 0),
  constraint pt_packages_used_chk check (used_sessions >= 0),
  constraint pt_packages_scheduled_chk check (scheduled_sessions >= 0),
  constraint pt_packages_used_total_chk check (used_sessions <= total_sessions)
);

create index if not exists pt_packages_client_idx on public.pt_packages(client_id);
create index if not exists pt_packages_purchase_idx on public.pt_packages(purchase_date desc);
create index if not exists pt_packages_expiry_idx on public.pt_packages(expiry_date);

-- ------------------------------------------------------------
-- MONTHLY SCHEDULE / CLIENT CALENDAR ONLINE RECORD
-- ------------------------------------------------------------
create table if not exists public.pt_schedules (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.pt_clients(id) on delete cascade,
  pt_user_id uuid references auth.users(id) on delete set null,
  scheduled_at timestamptz not null,
  schedule_type text,
  notes text,
  status text not null default 'SCHEDULED',
  session_state text,
  package_id uuid references public.pt_packages(id) on delete set null,
  sync_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pt_schedules_client_idx on public.pt_schedules(client_id);
create index if not exists pt_schedules_pt_idx on public.pt_schedules(pt_user_id);
create index if not exists pt_schedules_datetime_idx on public.pt_schedules(scheduled_at);
create unique index if not exists pt_schedules_sync_id_unique
  on public.pt_schedules(sync_id)
  where sync_id is not null;

-- ------------------------------------------------------------
-- CONDUCT / COMPLETED SESSION
-- ------------------------------------------------------------
create table if not exists public.pt_conducts (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.pt_clients(id) on delete cascade,
  package_id uuid references public.pt_packages(id) on delete set null,
  pt_user_id uuid references auth.users(id) on delete set null,
  conducted_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pt_conducts_client_idx on public.pt_conducts(client_id);
create index if not exists pt_conducts_pt_idx on public.pt_conducts(pt_user_id);
create index if not exists pt_conducts_datetime_idx on public.pt_conducts(conducted_at desc);

-- ------------------------------------------------------------
-- PACKAGE EXTENSION APPROVAL
-- ------------------------------------------------------------
create table if not exists public.pt_extension_requests (
  id uuid primary key default gen_random_uuid(),
  package_id uuid not null references public.pt_packages(id) on delete cascade,
  requested_by uuid references auth.users(id) on delete set null,
  requested_expiry date,
  reason text,
  status text not null default 'PENDING_APPROVAL',
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pt_extension_requests_package_idx on public.pt_extension_requests(package_id);
create index if not exists pt_extension_requests_status_idx on public.pt_extension_requests(status);
create index if not exists pt_extension_requests_created_idx on public.pt_extension_requests(created_at desc);

-- ------------------------------------------------------------
-- COMMON updated_at TRIGGER
-- ------------------------------------------------------------
create or replace function public.fj_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_access_updated_at on public.user_access;
create trigger trg_user_access_updated_at before update on public.user_access
for each row execute function public.fj_set_updated_at();

drop trigger if exists trg_pt_directory_updated_at on public.pt_directory;
create trigger trg_pt_directory_updated_at before update on public.pt_directory
for each row execute function public.fj_set_updated_at();

drop trigger if exists trg_pt_clients_updated_at on public.pt_clients;
create trigger trg_pt_clients_updated_at before update on public.pt_clients
for each row execute function public.fj_set_updated_at();

drop trigger if exists trg_pt_packages_updated_at on public.pt_packages;
create trigger trg_pt_packages_updated_at before update on public.pt_packages
for each row execute function public.fj_set_updated_at();

drop trigger if exists trg_pt_schedules_updated_at on public.pt_schedules;
create trigger trg_pt_schedules_updated_at before update on public.pt_schedules
for each row execute function public.fj_set_updated_at();

drop trigger if exists trg_pt_conducts_updated_at on public.pt_conducts;
create trigger trg_pt_conducts_updated_at before update on public.pt_conducts
for each row execute function public.fj_set_updated_at();

drop trigger if exists trg_pt_extension_requests_updated_at on public.pt_extension_requests;
create trigger trg_pt_extension_requests_updated_at before update on public.pt_extension_requests
for each row execute function public.fj_set_updated_at();

-- ------------------------------------------------------------
-- SESSION CONSUMPTION FUNCTION
-- Safe to create now; it is also compatible with the optional
-- V105_SESSION_MIGRATION.sql file.
-- ------------------------------------------------------------
create or replace function public.fj_consume_package_session(p_package_id uuid, p_sync_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  p public.pt_packages%rowtype;
  new_used integer;
begin
  if p_sync_id is null or length(trim(p_sync_id)) = 0 then
    raise exception 'sync_id_required';
  end if;

  if exists (
    select 1 from public.pt_schedules
    where sync_id = p_sync_id and session_state = 'USED'
  ) then
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;

  select * into p
  from public.pt_packages
  where id = p_package_id
  for update;

  if not found then raise exception 'package_not_found'; end if;
  if p.expiry_date is not null and p.expiry_date < current_date then
    raise exception 'package_expired';
  end if;
  if coalesce(p.used_sessions,0) >= coalesce(p.total_sessions,0) then
    raise exception 'no_sessions_available';
  end if;

  new_used := coalesce(p.used_sessions,0) + 1;
  update public.pt_packages
  set used_sessions = new_used,
      status = case
        when new_used >= coalesce(total_sessions,0) then 'CLOSED'
        else 'ACTIVE'
      end
  where id = p.id;

  return jsonb_build_object(
    'ok', true,
    'duplicate', false,
    'used_sessions', new_used,
    'remaining', greatest(0, coalesce(p.total_sessions,0) - new_used)
  );
end;
$$;

-- ------------------------------------------------------------
-- RLS HELPERS
-- Master Admin used by the current V105 app.
-- ------------------------------------------------------------
create or replace function public.fj_is_master_admin()
returns boolean
language sql
stable
as $$
  select lower(coalesce(auth.jwt()->>'email','')) = 'aldenkhafi0203@gmail.com';
$$;

-- ------------------------------------------------------------
-- ENABLE RLS
-- ------------------------------------------------------------
alter table public.user_access enable row level security;
alter table public.pt_directory enable row level security;
alter table public.pt_clients enable row level security;
alter table public.pt_packages enable row level security;
alter table public.pt_schedules enable row level security;
alter table public.pt_conducts enable row level security;
alter table public.pt_extension_requests enable row level security;

-- Remove/recreate only the policies owned by this setup script.
do $$
declare r record;
begin
  for r in select schemaname, tablename, policyname
           from pg_policies
           where schemaname='public'
             and tablename in ('user_access','pt_directory','pt_clients','pt_packages','pt_schedules','pt_conducts','pt_extension_requests')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- user_access: user can see own row; Master Admin can manage all.
create policy user_access_select on public.user_access
for select to authenticated
using (user_id = auth.uid() or public.fj_is_master_admin());

create policy user_access_insert on public.user_access
for insert to authenticated
with check (user_id = auth.uid());

create policy user_access_update on public.user_access
for update to authenticated
using (user_id = auth.uid() or public.fj_is_master_admin())
with check (user_id = auth.uid() or public.fj_is_master_admin());

-- PT directory: Admin manages; an approved PT may see/update their own directory row.
create policy pt_directory_select on public.pt_directory
for select to authenticated
using (user_id = auth.uid() or public.fj_is_master_admin());

create policy pt_directory_insert on public.pt_directory
for insert to authenticated
with check (user_id = auth.uid() or public.fj_is_master_admin());

create policy pt_directory_update on public.pt_directory
for update to authenticated
using (user_id = auth.uid() or public.fj_is_master_admin())
with check (user_id = auth.uid() or public.fj_is_master_admin());

create policy pt_directory_delete on public.pt_directory
for delete to authenticated
using (public.fj_is_master_admin());

-- Clients: Admin sees all; PT sees clients assigned to their auth user.
create policy pt_clients_select on public.pt_clients
for select to authenticated
using (public.fj_is_master_admin() or pt_user_id = auth.uid());

create policy pt_clients_insert on public.pt_clients
for insert to authenticated
with check (public.fj_is_master_admin() or pt_user_id = auth.uid());

create policy pt_clients_update on public.pt_clients
for update to authenticated
using (public.fj_is_master_admin() or pt_user_id = auth.uid())
with check (public.fj_is_master_admin() or pt_user_id = auth.uid());

create policy pt_clients_delete on public.pt_clients
for delete to authenticated
using (public.fj_is_master_admin() or pt_user_id = auth.uid());

-- Packages: access follows client ownership; Admin sees all.
create policy pt_packages_select on public.pt_packages
for select to authenticated
using (
  public.fj_is_master_admin() or exists (
    select 1 from public.pt_clients c
    where c.id = pt_packages.client_id and c.pt_user_id = auth.uid()
  )
);

create policy pt_packages_insert on public.pt_packages
for insert to authenticated
with check (
  public.fj_is_master_admin() or exists (
    select 1 from public.pt_clients c
    where c.id = pt_packages.client_id and c.pt_user_id = auth.uid()
  )
);

create policy pt_packages_update on public.pt_packages
for update to authenticated
using (
  public.fj_is_master_admin() or exists (
    select 1 from public.pt_clients c
    where c.id = pt_packages.client_id and c.pt_user_id = auth.uid()
  )
)
with check (
  public.fj_is_master_admin() or exists (
    select 1 from public.pt_clients c
    where c.id = pt_packages.client_id and c.pt_user_id = auth.uid()
  )
);

create policy pt_packages_delete on public.pt_packages
for delete to authenticated
using (public.fj_is_master_admin());

-- Schedules: Admin sees all; PT sees assigned PT/client records.
create policy pt_schedules_select on public.pt_schedules
for select to authenticated
using (
  public.fj_is_master_admin() or
  pt_user_id = auth.uid() or
  exists (select 1 from public.pt_clients c where c.id = pt_schedules.client_id and c.pt_user_id = auth.uid())
);

create policy pt_schedules_insert on public.pt_schedules
for insert to authenticated
with check (
  public.fj_is_master_admin() or
  pt_user_id = auth.uid() or
  exists (select 1 from public.pt_clients c where c.id = pt_schedules.client_id and c.pt_user_id = auth.uid())
);

create policy pt_schedules_update on public.pt_schedules
for update to authenticated
using (
  public.fj_is_master_admin() or
  pt_user_id = auth.uid() or
  exists (select 1 from public.pt_clients c where c.id = pt_schedules.client_id and c.pt_user_id = auth.uid())
)
with check (
  public.fj_is_master_admin() or
  pt_user_id = auth.uid() or
  exists (select 1 from public.pt_clients c where c.id = pt_schedules.client_id and c.pt_user_id = auth.uid())
);

create policy pt_schedules_delete on public.pt_schedules
for delete to authenticated
using (
  public.fj_is_master_admin() or
  pt_user_id = auth.uid() or
  exists (select 1 from public.pt_clients c where c.id = pt_schedules.client_id and c.pt_user_id = auth.uid())
);

-- Conducts: Admin sees all; PT sees own/assigned client records.
create policy pt_conducts_select on public.pt_conducts
for select to authenticated
using (
  public.fj_is_master_admin() or
  pt_user_id = auth.uid() or
  exists (select 1 from public.pt_clients c where c.id = pt_conducts.client_id and c.pt_user_id = auth.uid())
);

create policy pt_conducts_insert on public.pt_conducts
for insert to authenticated
with check (
  public.fj_is_master_admin() or
  pt_user_id = auth.uid() or
  exists (select 1 from public.pt_clients c where c.id = pt_conducts.client_id and c.pt_user_id = auth.uid())
);

create policy pt_conducts_update on public.pt_conducts
for update to authenticated
using (public.fj_is_master_admin() or pt_user_id = auth.uid())
with check (public.fj_is_master_admin() or pt_user_id = auth.uid());

create policy pt_conducts_delete on public.pt_conducts
for delete to authenticated
using (public.fj_is_master_admin() or pt_user_id = auth.uid());

-- Extension requests: Admin manages approvals; PT can create/read their package requests.
create policy pt_extension_requests_select on public.pt_extension_requests
for select to authenticated
using (
  public.fj_is_master_admin() or
  requested_by = auth.uid() or
  exists (
    select 1 from public.pt_packages p
    join public.pt_clients c on c.id = p.client_id
    where p.id = pt_extension_requests.package_id and c.pt_user_id = auth.uid()
  )
);

create policy pt_extension_requests_insert on public.pt_extension_requests
for insert to authenticated
with check (public.fj_is_master_admin() or requested_by = auth.uid());

create policy pt_extension_requests_update on public.pt_extension_requests
for update to authenticated
using (public.fj_is_master_admin() or requested_by = auth.uid())
with check (public.fj_is_master_admin() or requested_by = auth.uid());

-- ------------------------------------------------------------
-- Grants required by Supabase API. RLS remains the security boundary.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on function public.fj_consume_package_session(uuid,text) to authenticated;
grant execute on function public.fj_is_master_admin() to authenticated;

-- Keep future tables locked down by default; table grants are explicit above.
alter default privileges in schema public revoke execute on functions from public;

-- Verification summary. The SQL editor will return one row after setup.
select 'V105 NEW PROJECT DATABASE READY' as setup_status,
       (select count(*) from pg_tables where schemaname='public' and tablename in (
         'user_access','pt_directory','pt_clients','pt_packages','pt_schedules','pt_conducts','pt_extension_requests'
       )) as required_table_count;
