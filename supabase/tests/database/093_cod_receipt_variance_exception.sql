begin;

select plan(10);

select ok(
  (select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'enforce_cod_receipt_variance_state'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'COD receipt variance trigger function exists'
);

select ok(
  (select p.prorettype = 'pg_catalog.trigger'::regtype
          and p.prolang = (select oid from pg_language where lanname = 'plpgsql')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'enforce_cod_receipt_variance_state'),
  'variance function is a PL/pgSQL trigger function'
);

select ok(
  (select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public']
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'enforce_cod_receipt_variance_state'),
  'variance trigger uses SECURITY DEFINER and controlled search_path'
);

select ok(
  (select count(*) = 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relname = 'cod_receipts'
     and t.tgname = 'trg_cod_receipt_variance_state' and t.tgenabled <> 'D'),
  'COD receipt variance trigger is installed and enabled'
);

select ok(
  (select position('before insert' in lower(pg_get_triggerdef(t.oid))) > 0
   from pg_trigger t join pg_class c on c.oid = t.tgrelid
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relname = 'cod_receipts'
     and t.tgname = 'trg_cod_receipt_variance_state'),
  'variance state is determined before receipt insertion'
);

select ok(
  (select position('new.expected_amount_snapshot' in pg_get_functiondef(p.oid)) > 0
          and position('new.received_amount' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'enforce_cod_receipt_variance_state'),
  'variance state compares authoritative expected snapshot with received amount'
);

select ok(
  (select position('''Exception''' in pg_get_functiondef(p.oid)) > 0
          and position('''Received''' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'enforce_cod_receipt_variance_state'),
  'variance maps to Exception and exact collection maps to Received'
);

select ok(
  (select position('new.state := ''Exception''' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'enforce_cod_receipt_variance_state'),
  'non-matching amounts force Exception state'
);

select ok(
  (select position('new.state := ''Received''' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'enforce_cod_receipt_variance_state'),
  'matching amounts force Received state'
);

select ok(
  (select count(*) = 0 from information_schema.role_routine_grants
   where routine_schema = 'public' and routine_name = 'enforce_cod_receipt_variance_state'
     and grantee in ('public','anon','authenticated')),
  'variance trigger function is not directly executable by application roles'
);

select * from finish();
commit;
