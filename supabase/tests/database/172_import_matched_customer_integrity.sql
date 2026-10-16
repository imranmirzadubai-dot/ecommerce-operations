-- Regression guard for P12-T194: matched customer must still match the row phone.
begin;

select plan(4);

select ok(
  to_regprocedure('public.import_historical_batch(uuid,jsonb,text)') is not null,
  'historical import command exists'
);

select ok(
  (select p.prosecdef
   from pg_proc p
   where p.oid = 'public.import_historical_batch(uuid,jsonb,text)'::regprocedure),
  'historical import remains SECURITY DEFINER'
);

select ok(
  position('c.normalized_phone = v_phone' in lower(pg_get_functiondef(
    'public.import_historical_batch(uuid,jsonb,text)'::regprocedure
  ))) > 0,
  'matched customer must have the same normalized phone as the import row'
);

select ok(
  position('matched import row customer does not match normalized phone' in lower(pg_get_functiondef(
    'public.import_historical_batch(uuid,jsonb,text)'::regprocedure
  ))) > 0,
  'mismatched or missing matched customer is rejected explicitly'
);

select * from finish();
rollback;
