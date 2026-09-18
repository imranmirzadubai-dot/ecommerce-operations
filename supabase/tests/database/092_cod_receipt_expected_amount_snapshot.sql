-- P11-T172: COD receipt expected amount must be sourced from the
-- authoritative parcel allocation, not supplied by the client.
begin;

select plan(10);

select ok(
  (select count(*) = 1
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'record_cod_receipt'
     and pg_get_function_identity_arguments(p.oid) = 'p_cod_obligation_id uuid, p_parcel_id uuid, p_received_amount numeric, p_idempotency_key text'),
  'COD receipt command exposes no client-supplied expected snapshot parameter'
);

select ok(
  (select count(*) = 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'record_cod_receipt'
     and pg_get_function_identity_arguments(p.oid) = 'p_cod_obligation_id uuid, p_parcel_id uuid, p_expected_amount_snapshot numeric, p_received_amount numeric, p_idempotency_key text'),
  'legacy client-controlled receipt signature is removed'
);

select ok(
  (select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public']
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'record_cod_receipt'
     and pg_get_function_identity_arguments(p.oid) = 'p_cod_obligation_id uuid, p_parcel_id uuid, p_received_amount numeric, p_idempotency_key text'),
  'COD receipt command retains SECURITY DEFINER and controlled search_path'
);

select ok(
  (select position('public.cod_obligation_allocations' in pg_get_functiondef(p.oid)) > 0
          and position('v_allocation.expected_amount' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'record_cod_receipt'
     and pg_get_function_identity_arguments(p.oid) = 'p_cod_obligation_id uuid, p_parcel_id uuid, p_received_amount numeric, p_idempotency_key text'),
  'expected receipt amount is derived from the authoritative parcel allocation'
);

select ok(
  (select position('where cod_obligation_id = p_cod_obligation_id' in pg_get_functiondef(p.oid)) > 0
          and position('and parcel_id = p_parcel_id' in pg_get_functiondef(p.oid)) > 0
          and position('for update' in lower(pg_get_functiondef(p.oid))) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'record_cod_receipt'
     and pg_get_function_identity_arguments(p.oid) = 'p_cod_obligation_id uuid, p_parcel_id uuid, p_received_amount numeric, p_idempotency_key text'),
  'authoritative parcel allocation is locked before snapshot use'
);

select ok(
  (select position('v_allocation.expected_amount' in pg_get_functiondef(p.oid)) > 0
          and position('expected_amount_snapshot' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'record_cod_receipt'
     and pg_get_function_identity_arguments(p.oid) = 'p_cod_obligation_id uuid, p_parcel_id uuid, p_received_amount numeric, p_idempotency_key text'),
  'receipt snapshot is populated from the allocation amount'
);

select ok(
  (select position('COD expected amount allocation not found for parcel' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'record_cod_receipt'
     and pg_get_function_identity_arguments(p.oid) = 'p_cod_obligation_id uuid, p_parcel_id uuid, p_received_amount numeric, p_idempotency_key text'),
  'receipt entry rejects parcels without an authoritative expected amount allocation'
);

select ok(
  (select position('claim_command_idempotency' in pg_get_functiondef(p.oid)) > 0
          and position('complete_command_idempotency' in pg_get_functiondef(p.oid)) > 0
          and position('p_received_amount::text' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'record_cod_receipt'
     and pg_get_function_identity_arguments(p.oid) = 'p_cod_obligation_id uuid, p_parcel_id uuid, p_received_amount numeric, p_idempotency_key text'),
  'receipt entry remains idempotent using only authoritative identity plus received amount'
);

select ok(
  (select not has_function_privilege('public', 'public.record_cod_receipt(uuid,uuid,numeric,text)', 'execute')
          and not has_function_privilege('anon', 'public.record_cod_receipt(uuid,uuid,numeric,text)', 'execute')
          and has_function_privilege('authenticated', 'public.record_cod_receipt(uuid,uuid,numeric,text)', 'execute')
   ),
  'receipt command grants execution only to authenticated browser callers'
);

select ok(
  (select position('v_allocation.expected_amount,' in replace(pg_get_functiondef(p.oid), E'\n', ' ')) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'record_cod_receipt'
     and pg_get_function_identity_arguments(p.oid) = 'p_cod_obligation_id uuid, p_parcel_id uuid, p_received_amount numeric, p_idempotency_key text'),
  'inserted receipt expected snapshot is the locked allocation value'
);

select * from finish();
rollback;
