-- P15-T230: invoice snapshot capture must not use min(uuid), which PostgreSQL does not support.
begin;

select plan(3);

select ok(
  (select position('min(p.id)' in pg_get_functiondef(p.oid)) = 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'capture_invoice_historical_snapshot'),
  'invoice snapshot capture does not use unsupported min(uuid)'
);

select ok(
  (select position('select p.id into v_parcel_id' in pg_get_functiondef(p.oid)) > 0
          and position('order by p.id' in pg_get_functiondef(p.oid)) > 0
          and position('limit 1' in lower(pg_get_functiondef(p.oid))) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'capture_invoice_historical_snapshot'),
  'invoice snapshot capture selects the single parcel UUID deterministically'
);

select ok(
  (select position('v_parcel_count <> 1' in pg_get_functiondef(p.oid)) > 0
          and position('Invoice generation requires exactly one parcel for the order' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'capture_invoice_historical_snapshot'),
  'invoice snapshot capture retains the exactly-one-parcel invariant'
);

select * from finish();
rollback;
