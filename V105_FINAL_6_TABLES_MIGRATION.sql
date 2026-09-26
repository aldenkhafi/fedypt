-- FITNESS JOURNEY V105 FINAL — exactly 6 PT Management tables
begin;

drop table if exists public.pt_extension_requests cascade;

update public.pt_packages
set status = case
  when coalesce(used_sessions,0) >= coalesce(total_sessions,0) then 'CLOSED'
  when expiry_date is null or expiry_date >= current_date then 'ACTIVE'
  else 'EXPIRED'
end
where status = 'EXTEND_REQUESTED';

commit;

-- Final application tables: user_access, pt_directory, pt_clients, pt_packages, pt_schedules, pt_conducts
