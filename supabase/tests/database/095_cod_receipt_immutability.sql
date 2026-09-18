-- P11-T175: original COD receipt immutability database contract.
begin;

select plan(10);

select ok(
  (select count(*) = 1
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'prevent_cod_receipt_mutation'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'COD receipt mutation guard function exists'
);

select ok(
  (select p.prosecdef
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'prevent_cod_receipt_mutation'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'COD receipt mutation guard is SECURITY DEFINER'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%SET search_path TO %pg_catalog%public%'
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'prevent_cod_receipt_mutation'
     and pg_get_function_identity_arguments(p.oid) = ''),
  'COD receipt mutation guard uses a controlled search_path'
);

select ok(
  (select count(*) = 1
   from pg_trigger t
   join pg_class c on c.oid = t.tgrelid
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'cod_receipts'
     and t.tgname = 'cod_receipts_immutable_update'
     and not t.tgisinternal
     and (t.tgtype & 16) <> 0
     and (t.tgtype & 8) <> 0),
  'COD receipt immutability trigger covers UPDATE and DELETE'
);

select ok(
  (select position('BEFORE' in upper(pg_get_triggerdef(t.oid))) > 0
       and position('UPDATE' in upper(pg_get_triggerdef(t.oid))) > 0
       and position('DELETE' in upper(pg_get_triggerdef(t.oid))) > 0
   from pg_trigger t
   join pg_class c on c.oid = t.tgrelid
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'cod_receipts'
     and t.tgname = 'cod_receipts_immutable_update'),
  'immutability trigger fires before mutation'
);

select ok(
  (select pg_get_triggerdef(t.oid) like '%prevent_cod_receipt_mutation()%'
   from pg_trigger t
   join pg_class c on c.oid = t.tgrelid
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'cod_receipts'
     and t.tgname = 'cod_receipts_immutable_update'),
  'immutability trigger invokes the authoritative mutation guard'
);

select ok(
  (select not has_table_privilege('public', 'public.cod_receipts', 'UPDATE')),
  'public role has no direct COD receipt UPDATE privilege'
);

select ok(
  (select not has_table_privilege('anon', 'public.cod_receipts', 'DELETE')),
  'anon role has no direct COD receipt DELETE privilege'
);

select ok(
  (select not has_table_privilege('authenticated', 'public.cod_receipts', 'UPDATE')),
  'authenticated role has no direct COD receipt UPDATE privilege'
);

select ok(
  (select has_table_privilege('authenticated', 'public.cod_receipts', 'SELECT')),
  'authenticated role retains read-only COD receipt access'
);

select * from finish();
rollback;
