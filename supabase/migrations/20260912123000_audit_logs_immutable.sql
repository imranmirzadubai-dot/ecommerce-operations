begin;

create or replace function public.prevent_audit_log_mutation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'audit logs are immutable; append a new audit record instead'
    using errcode = '55000';
end;
$$;

revoke all on function public.prevent_audit_log_mutation() from public;

drop trigger if exists trg_audit_logs_immutable on public.audit_logs;
create trigger trg_audit_logs_immutable
before update or delete on public.audit_logs
for each row execute function public.prevent_audit_log_mutation();

alter table public.audit_logs enable row level security;
revoke all on public.audit_logs from anon;
revoke all on public.audit_logs from authenticated;
grant select on public.audit_logs to authenticated;

commit;
