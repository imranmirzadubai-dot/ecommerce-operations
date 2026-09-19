begin;

select plan(12);

-- P12-T198 is an approval/evidence gate, not a production-data import.
-- The regression verifies that the production import contract is gated correctly
-- and that the approval step cannot be mistaken for execution of production data.

select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'import_historical_batch'
      and pg_get_function_arguments(p.oid) = 'p_batch_id uuid, p_field_map jsonb, p_idempotency_key text'
  ),
  'authoritative historical production import command exists'
);

select ok(
  position('security definer' in lower(pg_get_functiondef(p.oid))) > 0,
  'production import command is SECURITY DEFINER'
) from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'import_historical_batch';

select ok(
  position('search_path = pg_catalog, public' in lower(pg_get_functiondef(p.oid))) > 0,
  'production import command fixes search_path'
) from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'import_historical_batch';

select ok(
  position('v_status <> ''ready''' in lower(pg_get_functiondef(p.oid))) > 0,
  'production import requires Ready batch status'
) from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'import_historical_batch';

select ok(
  position('v_staging_reconciled' in lower(pg_get_functiondef(p.oid))) > 0
  and position('v_monetary_reconciled' in lower(pg_get_functiondef(p.oid))) > 0,
  'production import requires both reconciliation results'
) from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'import_historical_batch';

select ok(
  position('claim_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0
  and position('complete_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0,
  'production import uses command idempotency'
) from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'import_historical_batch';

select ok(
  position('insert into public.orders' in lower(pg_get_functiondef(p.oid))) > 0
  and position('original_amount' in lower(pg_get_functiondef(p.oid))) > 0
  and position('''completed''' in lower(pg_get_functiondef(p.oid))) > 0,
  'production import creates historical orders with authoritative amount and Completed state'
) from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'import_historical_batch';

select ok(
  position('insert into public.order_items' in lower(pg_get_functiondef(p.oid))) > 0,
  'production import creates one order item per staged source row'
) from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'import_historical_batch';

select ok(
  position('historical import' in lower(pg_get_functiondef(p.oid))) > 0
  and position('source_row_number' in lower(pg_get_functiondef(p.oid))) > 0
  and position('source_record_id' in lower(pg_get_functiondef(p.oid))) > 0
  and position('source_identity' in lower(pg_get_functiondef(p.oid))) > 0,
  'production import emits historical-import source lineage metadata'
) from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'import_historical_batch';

select ok(
  position('insert into public.parcels' in lower(pg_get_functiondef(p.oid))) = 0,
  'production import does not allocate parcels'
) from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'import_historical_batch';

select ok(
  not has_function_privilege('anon', 'public.import_historical_batch(uuid,jsonb,text)', 'EXECUTE'),
  'anonymous execution of production import is revoked'
);

select ok(
  has_function_privilege('authenticated', 'public.import_historical_batch(uuid,jsonb,text)', 'EXECUTE'),
  'authenticated entry point remains available for server-side Admin role gating'
);

select finish();
rollback;
