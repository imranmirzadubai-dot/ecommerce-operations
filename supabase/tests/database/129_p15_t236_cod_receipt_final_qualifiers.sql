begin;
select plan(3);
select ok(
  (select pg_get_functiondef(p.oid) like '%from public.cod_receipts cr%where cr.parcel_id=p_parcel_id%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.prokind='f' and p.proname='record_cod_receipt'),
  'record_cod_receipt qualifies receipt lookup parcel_id'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%from public.cod_obligation_allocations a%where a.cod_obligation_id=p_cod_obligation_id%and a.parcel_id=p_parcel_id%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.prokind='f' and p.proname='record_cod_receipt'),
  'record_cod_receipt qualifies allocation lookup'
);
select ok(
  (select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_cod_receipt'
   and pg_get_function_identity_arguments(p.oid)='p_cod_obligation_id uuid, p_parcel_id uuid, p_received_amount numeric, p_idempotency_key text'),
  'record_cod_receipt canonical signature retained'
);
select * from finish();
rollback;