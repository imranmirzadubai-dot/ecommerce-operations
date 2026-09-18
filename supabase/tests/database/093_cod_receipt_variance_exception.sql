begin;

select plan(10);

select has_function(
  'public',
  'enforce_cod_receipt_variance_state',
  'P11-T173 variance trigger function exists'
);

select is(
  (select prosecdef from pg_proc where oid = 'public.enforce_cod_receipt_variance_state()'::regprocedure),
  true,
  'P11-T173 trigger function is SECURITY DEFINER'
);

select is(
  (select proconfig from pg_proc where oid = 'public.enforce_cod_receipt_variance_state()'::regprocedure),
  array['search_path=pg_catalog, public']::text[],
  'P11-T173 trigger function uses controlled search_path'
);

select has_trigger(
  'public',
  'cod_receipts',
  'trg_cod_receipt_variance_state',
  'P11-T173 cod_receipts variance trigger exists'
);

select ok(
  position('received_amount <> expected_amount_snapshot' in pg_get_functiondef('public.enforce_cod_receipt_variance_state()'::regprocedure)) > 0,
  'P11-T173 detects non-zero receipt variance'
);

select ok(
  position('new.state := ''Exception''' in pg_get_functiondef('public.enforce_cod_receipt_variance_state()'::regprocedure)) > 0,
  'P11-T173 assigns Exception for variance'
);

select ok(
  position('new.state := ''Received''' in pg_get_functiondef('public.enforce_cod_receipt_variance_state()'::regprocedure)) > 0,
  'P11-T173 preserves Received for exact match'
);

select ok(
  position('BEFORE INSERT OR UPDATE' in upper(pg_get_triggerdef(t.oid))) > 0,
  'P11-T173 trigger runs before receipt writes'
)
from pg_trigger t
where t.tgrelid = 'public.cod_receipts'::regclass
  and t.tgname = 'trg_cod_receipt_variance_state';

select is(
  (select has_function_privilege('public', 'public.enforce_cod_receipt_variance_state()', 'execute')),
  false,
  'P11-T173 trigger function is not executable by public'
);

select is(
  (select has_function_privilege('authenticated', 'public.enforce_cod_receipt_variance_state()', 'execute')),
  false,
  'P11-T173 trigger function is not directly executable by authenticated users'
);

select * from finish();

rollback;
