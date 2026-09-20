begin;

select plan(10);
set local role postgres;

-- Rollback-scoped application-database characterization. This creates synthetic
-- orders/parcels only; it is not production capacity certification.
insert into auth.users (id, aud, role, email, encrypted_password)
values ('00000000-0000-0000-0000-000000000311'::uuid, 'authenticated', 'authenticated', 'bulk-dispatch-load@example.test', 'test-only');
insert into public.profiles(id,name,email,role,active)
values ('00000000-0000-0000-0000-000000000311'::uuid,'Bulk Dispatch Load Test','bulk-dispatch-load@example.test','admin',true);

insert into public.customers(id,name,phone,normalized_phone,address,city)
select
  ('11000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  'Bulk Customer ' || g,
  '051000' || lpad(g::text,6,'0'),
  '051000' || lpad(g::text,6,'0'),
  'Bulk Load Address',
  case when g % 3 = 0 then 'Dubai' when g % 3 = 1 then 'Sharjah' else 'Ajman' end
from generate_series(1,5000) g;

insert into public.orders(id,customer_id,order_date,currency_code,original_amount,lifecycle_state,notes,created_by)
select
  ('21000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  ('11000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  current_date,
  'AED',
  (100 + (g % 300))::numeric(12,2),
  'Confirmed',
  'P14-T211 synthetic bulk dispatch row',
  '00000000-0000-0000-0000-000000000311'::uuid
from generate_series(1,5000) g;

insert into public.parcels(id,order_id,barcode,state)
select
  ('31000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  ('21000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  'P14-T211-' || lpad(g::text,6,'0'),
  'Prepared'
from generate_series(1,5000) g;

select is((select count(*) from public.parcels where barcode like 'P14-T211-%'),5000::bigint,'5,000 synthetic parcels loaded');
select is((select count(*) from public.parcels where state='Prepared' and barcode like 'P14-T211-%'),5000::bigint,'5,000 parcels initially Prepared');

-- Bulk barcode scan simulation: 1,000 exact barcode lookups using the unique barcode index.
do $$
declare
  started timestamptz;
  elapsed_ms numeric;
  found_count bigint;
begin
  started := clock_timestamp();
  select count(*) into found_count
  from public.parcels p
  where p.barcode in (
    select 'P14-T211-' || lpad(g::text,6,'0') from generate_series(1,1000) g
  );
  elapsed_ms := extract(epoch from (clock_timestamp()-started))*1000;
  perform is(found_count,1000::bigint,'bulk scan resolves 1,000 exact parcel barcodes');
  perform ok(elapsed_ms < 5000,'bulk scan lookup completes within 5s');
end $$;

-- Bulk dispatch simulation: transition all 5,000 prepared parcels atomically.
do $$
declare
  started timestamptz;
  elapsed_ms numeric;
  affected_count bigint;
begin
  started := clock_timestamp();
  update public.parcels
     set state='Dispatched', dispatch_at=clock_timestamp(), updated_at=clock_timestamp()
   where state='Prepared'
     and barcode like 'P14-T211-%';
  get diagnostics affected_count = row_count;
  elapsed_ms := extract(epoch from (clock_timestamp()-started))*1000;
  perform is(affected_count,5000::bigint,'bulk dispatch updates all 5,000 parcels');
  perform ok(elapsed_ms < 5000,'bulk dispatch completes within 5s for 5,000 parcels');
end $$;

select is((select count(*) from public.parcels where state='Dispatched' and barcode like 'P14-T211-%'),5000::bigint,'all 5,000 parcels are Dispatched after bulk transition');
select ok((select count(*) from public.parcels where dispatch_at is not null and barcode like 'P14-T211-%')=5000,'all dispatched parcels have dispatch timestamps');
select is((select count(*) from public.orders where notes='P14-T211 synthetic bulk dispatch row'),5000::bigint,'source order dataset remains intact');

select * from finish();
rollback;
