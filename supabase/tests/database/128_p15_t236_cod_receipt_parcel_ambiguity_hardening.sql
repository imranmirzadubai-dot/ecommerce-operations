begin;
select plan(5);

select ok(
  (select pg_get_functiondef(p.oid) like '%from public.cod_obligation_allocations a%where a.cod_obligation_id=p_cod_obligation_id%and a.parcel_id=p_parcel_id%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.prokind='f' and p.proname='record_cod_receipt'),
  'record_cod_receipt qualifies allocation lookup'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%from public.cod_receipts cr%where cr.parcel_id=p_parcel_id%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.prokind='f' and p.proname='record_cod_receipt'),
  'record_cod_receipt qualifies receipt parcel lookup'
);

select ok(
  (select pg_get_functiondef(p.oid) not like '%from public.cod_receipts%where parcel_id=p_parcel_id%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.prokind='f' and p.proname='record_cod_receipt'),
  'record_cod_receipt has no unqualified parcel_id lookup'
);

select ok(
  (select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_cod_receipt'
   and pg_get_function_identity_arguments(p.oid)='p_cod_obligation_id uuid, p_parcel_id uuid, p_received_amount numeric, p_idempotency_key text'),
  'record_cod_receipt keeps canonical signature'
);

select ok(
  (select count(*)=1 from pg_trigger where tgrelid='public.cod_receipts'::regclass
   and tgname='trg_cod_receipt_variance_state' and not tgisinternal),
  'COD receipt variance trigger remains installed'
);

select * from finish();
rollback;