-- P11-T169: parcel expected COD allocation sum invariant contract.
begin;

select plan(10);

select ok(
  (select count(*) = 1
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'enforce_cod_allocation_sum_invariant'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'COD allocation sum invariant trigger function exists'
);

select ok(
  (select p.prosecdef
          and p.proconfig @> array['search_path=pg_catalog, public']
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'enforce_cod_allocation_sum_invariant'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'COD allocation sum invariant retains SECURITY DEFINER and controlled search_path'
);

select ok(
  (select count(*) = 1
   from pg_trigger t
   join pg_class c on c.oid = t.tgrelid
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'cod_obligation_allocations'
     and t.tgname = 'cod_obligation_allocations_sum_invariant'
     and not t.tgisinternal),
  'allocation changes are guarded by the sum invariant trigger'
);

select ok(
  (select count(*) = 1
   from pg_trigger t
   join pg_class c on c.oid = t.tgrelid
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'cod_obligations'
     and t.tgname = 'cod_obligations_sum_invariant'
     and not t.tgisinternal),
  'obligation state/amount changes are guarded by the sum invariant trigger'
);

select ok(
  (select position('sum(expected_amount)' in pg_get_functiondef(p.oid)) > 0
          and position('cod_obligation_allocations' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'enforce_cod_allocation_sum_invariant'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'invariant derives the parcel allocation total from authoritative allocation rows'
);

select ok(
  (select position('for update' in lower(pg_get_functiondef(p.oid))) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'enforce_cod_allocation_sum_invariant'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'invariant serializes reconciliation through the authoritative COD obligation row lock'
);

select ok(
  (select position('v_allocated > v_obligation.expected_amount' in pg_get_functiondef(p.oid)) > 0
          and position('exceeds obligation' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'enforce_cod_allocation_sum_invariant'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'allocation total may never exceed the order-level COD obligation'
);

select ok(
  (select position("v_obligation.state in ('Received','Closed')" in pg_get_functiondef(p.oid)) > 0
          and position('v_allocated <> v_obligation.expected_amount' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'enforce_cod_allocation_sum_invariant'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'Received and Closed obligations require exact allocation reconciliation'
);

select ok(
  (select not has_function_privilege('public', 'public.enforce_cod_allocation_sum_invariant()', 'execute')
          and not has_function_privilege('anon', 'public.enforce_cod_allocation_sum_invariant()', 'execute')
          and not has_function_privilege('authenticated', 'public.enforce_cod_allocation_sum_invariant()', 'execute')),
  'sum invariant trigger function is not directly executable by browser roles'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%coalesce(new.cod_obligation_id, old.cod_obligation_id)%'
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'enforce_cod_allocation_sum_invariant'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'allocation INSERT/UPDATE/DELETE paths resolve the affected obligation deterministically'
);

select * from finish();
rollback;
