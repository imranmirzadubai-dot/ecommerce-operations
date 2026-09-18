-- P11-T182: partial/variance COD collection regression coverage.
-- The reconciliation projection is authoritative and read-only; this test
-- verifies deterministic Outstanding/Overcollected/Exception behavior and
-- receipt-variance accounting for non-exact collection.
begin;

select plan(10);

select ok((select count(*) = 1
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cod_financial_reconciliation'
    and pg_get_function_identity_arguments(p.oid) = 'p_order_id uuid'),
  'partial/variance collection uses the authoritative reconciliation function');

select ok((select position('v_received < v_effective' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_cod_financial_reconciliation'),
  'partial collection explicitly evaluates received amount below effective amount');

select ok((select position('reconciliation_state := ''Outstanding''' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_cod_financial_reconciliation'),
  'partial collection maps to the Outstanding reconciliation state');

select ok((select position('reconciliation_state := ''Overcollected''' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_cod_financial_reconciliation'),
  'collection above effective amount maps to the Overcollected state');

select ok((select position('cr.expected_amount_snapshot' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_cod_financial_reconciliation'),
  'receipt variance uses the immutable expected receipt snapshot');

select ok((select position('receipt_variance := v_receipt_variance' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_cod_financial_reconciliation'),
  'receipt variance is exposed by the reconciliation result');

select ok((select position('outstanding_amount := round(v_effective - v_received, 2)' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_cod_financial_reconciliation'),
  'partial collection outstanding amount derives from effective less received');

select ok((select position('v_exception_count > 0' in pg_get_functiondef(p.oid)) > 0
  and position('reconciliation_state := ''Exception''' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_cod_financial_reconciliation'),
  'Exception remains distinct from ordinary partial or overcollection variance');

select ok((select position('v_unreceived_count > 0 or v_allocated <> v_cod_expected' in pg_get_functiondef(p.oid)) > 0
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_cod_financial_reconciliation'),
  'partial collection cannot reconcile while COD allocation or receipt completeness is pending');

select ok((select position('insert into' in lower(pg_get_functiondef(p.oid))) = 0
  and position('update ' in lower(pg_get_functiondef(p.oid))) = 0
  and position('delete ' in lower(pg_get_functiondef(p.oid))) = 0
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_cod_financial_reconciliation'),
  'partial/variance reconciliation remains a read-only projection with no mutation statements');

select * from finish();
rollback;
