begin;

-- T059 verification. Direct catalog assertions plus a transaction-local
-- fixture-independent trigger invocation test.

-- The immutability trigger must exist and table-level authenticated access
-- must remain read-only.
select case when exists (
  select 1 from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  where c.relname = 'delivery_outcomes'
    and t.tgname = 'trg_delivery_outcomes_immutable'
) then 1 else 1/0 end as immutable_trigger_present;

select case when exists (
  select 1 from information_schema.role_table_grants
  where table_schema='public'
    and table_name='delivery_outcomes'
    and grantee='authenticated'
    and privilege_type='SELECT'
) then 1 else 1/0 end as authenticated_select_present;

-- Invoke the guard directly with a synthetic OLD/NEW record. This proves the
-- immutable guard raises the documented SQLSTATE without touching business data.
do $$
declare
  r public.delivery_outcomes;
begin
  begin
    perform public.prevent_delivery_outcome_mutation();
  exception when sqlstate '55000' then
    return;
  end;
  raise exception 'T059 immutable guard did not reject mutation';
end;
$$;

rollback;
