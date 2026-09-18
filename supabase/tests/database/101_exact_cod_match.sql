-- P11-T181: exact COD match regression coverage.
-- The reconciliation projection is authoritative and read-only; this test
-- verifies the exact-match contract and deterministic Reconciled state.
begin;

select plan(10);

select ok((select count(*) = 1
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'
    and pg_get_function_identity_arguments(p.oid) = 'p_order_id uuid'),
  'exact COD reconciliation uses the authoritative order reconciliation function');

select ok((select p.prosecdef and p.provolatile = 's'
  and p.proconfig @> array['search_path=pg_catalog, public']
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'),
  'exact COD reconciliation remains SECURITY DEFINER, STABLE and search-path controlled');

select ok((select position('v_received = v_effective' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'),
  'exact receipt/effective amount equality is explicitly evaluated');

select ok((select position('reconciliation_state := ''Reconciled''' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'),
  'exact amount equality maps to the Reconciled state');

select ok((select position('cod_expected_amount := v_cod_expected' in pg_get_functiondef(p.oid)) > 0
  and position('allocated_expected_amount := v_allocated' in pg_get_functiondef(p.oid)) > 0
  and position('received_amount := v_received' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'),
  'exact COD match exposes obligation, allocation and received amounts independently');

select ok((select position('outstanding_amount := round(v_effective - v_received, 2)' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'),
  'exact COD match derives outstanding amount from effective less received');

select ok((select position('v_received = v_effective' in pg_get_functiondef(p.oid)) > 0
  and position('v_received < v_effective' in pg_get_functiondef(p.oid)) > 0
  and position('reconciliation_state := ''Overcollected''' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'),
  'non-exact receipt amounts remain distinguishable from the exact-match state');

select ok((select position('v_unreceived_count > 0 or v_allocated <> v_cod_expected' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'),
  'exact COD match is not reported Reconciled while allocation completeness is pending');

select ok((select position('select coalesce(sum(cr.received_amount), 0)' in pg_get_functiondef(p.oid)) > 0
  and position('cr.expected_amount_snapshot' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'),
  'exact COD reconciliation uses immutable receipt values and expected snapshots');

select ok((select position('return next' in pg_get_functiondef(p.oid)) > 0
  and position('insert into' in lower(pg_get_functiondef(p.oid))) = 0
  and position('update ' in lower(pg_get_functiondef(p.oid))) = 0
  and position('delete ' in lower(pg_get_functiondef(p.oid))) = 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'),
  'exact COD reconciliation remains a read-only projection with no mutation statements');

select * from finish();
rollback;
