begin;

-- T060 structural/security verification. Staging has no fixture data, so
-- behavioral lifecycle mutation is intentionally left to command-layer tests.

DO $$
begin
  if not exists (select 1 from pg_constraint where conrelid='public.cod_obligations'::regclass and contype='u' and conname='cod_obligations_order_id_key') then
    raise exception 'T060 order uniqueness missing';
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.cod_obligations'::regclass and conname='cod_obligations_expected_amount_check') then
    raise exception 'T060 expected amount check missing';
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.cod_obligations'::regclass and conname='cod_obligations_state_check') then
    raise exception 'T060 state check missing';
  end if;
end $$;

select
  (select data_type='numeric' and numeric_precision=12 and numeric_scale=2 from information_schema.columns where table_schema='public' and table_name='cod_obligations' and column_name='expected_amount') as expected_amount_numeric,
  (select relrowsecurity from pg_class where oid='public.cod_obligations'::regclass) as rls_enabled,
  (select count(*)=1 from information_schema.role_table_grants where table_schema='public' and table_name='cod_obligations' and grantee='authenticated' and privilege_type='SELECT') as auth_select_only,
  (select count(*)=0 from information_schema.role_table_grants where table_schema='public' and table_name='cod_obligations' and grantee='authenticated' and privilege_type in ('INSERT','UPDATE','DELETE')) as auth_writes_denied;

rollback;
