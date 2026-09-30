-- P15-T241: report-view authorization contract.
-- This is catalog-level regression coverage for the report security boundary.

do $$
declare
  v record;
begin
  for v in
    select c.relname, c.reloptions
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'v'
      and c.relname like 'report_%'
  loop
    if not exists (
      select 1
      from unnest(coalesce(v.reloptions, array[]::text[])) option
      where option = 'security_invoker=true'
    ) then
      raise exception 'P15-T241: report view % is not security_invoker', v.relname;
    end if;
  end loop;

  if exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee = 'authenticated'
      and table_name like 'report_%'
      and privilege_type <> 'SELECT'
  ) then
    raise exception 'P15-T241: authenticated has non-SELECT privilege on a report view';
  end if;

  if exists (
    select 1
    from information_schema.table_privileges
    where table_schema = 'public'
      and grantee = 'anon'
      and table_name like 'report_%'
  ) then
    raise exception 'P15-T241: anon has privileges on a report view';
  end if;
end $$;
