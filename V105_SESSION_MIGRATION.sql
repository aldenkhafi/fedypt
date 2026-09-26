-- Optional hardening migration for V105 Session Management.
-- The current app has a backward-compatible fallback using notes JSON.
-- Run this in Supabase SQL Editor to make session accounting strongly atomic.

alter table public.pt_schedules add column if not exists session_state text;
alter table public.pt_schedules add column if not exists package_id uuid;
alter table public.pt_schedules add column if not exists sync_id text;
alter table public.pt_packages add column if not exists scheduled_sessions integer not null default 0;

create unique index if not exists pt_schedules_sync_id_unique
on public.pt_schedules(sync_id)
where sync_id is not null;

create or replace function public.fj_consume_package_session(p_package_id uuid, p_sync_id text)
returns jsonb
language plpgsql
security definer
as $$
declare
  p public.pt_packages%rowtype;
  new_used integer;
begin
  if p_sync_id is null or length(trim(p_sync_id))=0 then
    raise exception 'sync_id_required';
  end if;

  if exists (select 1 from public.pt_schedules where sync_id=p_sync_id and session_state='USED') then
    return jsonb_build_object('ok',true,'duplicate',true);
  end if;

  select * into p
  from public.pt_packages
  where id=p_package_id
  for update;

  if not found then raise exception 'package_not_found'; end if;
  if coalesce(p.expiry_date,current_date) < current_date then raise exception 'package_expired'; end if;
  if coalesce(p.used_sessions,0) >= coalesce(p.total_sessions,0) then raise exception 'no_sessions_available'; end if;

  new_used := coalesce(p.used_sessions,0)+1;
  update public.pt_packages
  set used_sessions=new_used,
      status=case when new_used >= coalesce(total_sessions,0) then 'CLOSED' else 'ACTIVE' end
  where id=p.id;

  return jsonb_build_object('ok',true,'duplicate',false,'used_sessions',new_used,'remaining',greatest(0,coalesce(p.total_sessions,0)-new_used));
end;
$$;
