begin;

select plan(11);
set local role postgres;

-- P14-T212: deterministic, rollback-scoped RTO load characterization.
-- This is an application-database workload test, not a production RTO SLA,
-- disaster-recovery test, or multi-client stress certification.

insert into auth.users (id, aud, role, email, encrypted_password)
values ('00000000-0000-0000-0000-000000000320'::uuid, 'authenticated', 'authenticated', 'rto-load@example.test', 'test-only');
insert into public.profiles(id,name,email,role,active)
values ('00000000-0000-0000-0000-000000000320'::uuid,'RTO Load Test','rto-load@example.test','admin',true);

insert into public.customers(id,name,phone,normalized_phone,address,city)
select
  ('11000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  'RTO Customer ' || g,
  '051000' || lpad(g::text,6,'0'),
  '051000' || lpad(g::text,6,'0'),
  'RTO Load Test Address',
  case when g % 3 = 0 then 'Dubai' when g % 3 = 1 then 'Sharjah' else 'Ajman' end
from generate_series(1,5000) g;

insert into public.orders(id,customer_id,order_date,currency_code,original_amount,lifecycle_state,notes,created_by)
select
  ('21000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  ('11000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  current_date - ((g-1) % 30),
  'AED',
  (75 + (g % 400))::numeric(12,2),
  'Active',
  'P14-T212 synthetic RTO load row',
  '00000000-0000-0000-0000-000000000320'::uuid
from generate_series(1,5000) g;

insert into public.parcels(id,order_id,barcode,state,dispatch_at)
select
  ('31000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  ('21000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  'P14T212-' || lpad(g::text,6,'0'),
  'In Transit',
  clock_timestamp() - interval '2 hours'
from generate_series(1,5000) g;

select is((select count(*) from public.parcels p join public.orders o on o.id=p.order_id where o.notes='P14-T212 synthetic RTO load row'),5000::bigint,'5,000 synthetic parcels loaded for RTO workload');

do $$
declare
  started timestamptz;
  elapsed_ms numeric;
  changed_count bigint;
  rto_time timestamptz := clock_timestamp();
begin
  started := clock_timestamp();
  update public.parcels p
  set state='RTO', rto_at=rto_time, updated_at=rto_time
  from public.orders o
  where o.id=p.order_id and o.notes='P14-T212 synthetic RTO load row' and p.state='In Transit';
  get diagnostics changed_count = row_count;
  elapsed_ms := extract(epoch from (clock_timestamp()-started))*1000;
  perform is(changed_count,5000::bigint,'bulk RTO transition changes all 5,000 parcels');
  perform ok(elapsed_ms < 5000,'bulk RTO transition completes within 5s characterization budget');
end $$;

insert into public.delivery_outcomes(parcel_id,outcome,note,occurred_at,performed_by)
select p.id,'RTO','P14-T212 synthetic RTO outcome',p.rto_at,'00000000-0000-0000-0000-000000000320'::uuid
from public.parcels p join public.orders o on o.id=p.order_id
where o.notes='P14-T212 synthetic RTO load row';

select is((select count(*) from public.delivery_outcomes d where d.note='P14-T212 synthetic RTO outcome'),5000::bigint,'5,000 RTO delivery outcomes recorded');
select is((select count(*) from public.parcels p join public.orders o on o.id=p.order_id where o.notes='P14-T212 synthetic RTO load row' and p.state='RTO' and p.rto_at is not null),5000::bigint,'all RTO parcels have RTO timestamp');
select is((select count(*) from public.delivery_outcomes d where d.note='P14-T212 synthetic RTO outcome' and d.outcome='RTO'),5000::bigint,'all recorded delivery outcomes are RTO');

do $$
declare
  started timestamptz;
  elapsed_ms numeric;
  result_count bigint;
begin
  started := clock_timestamp();
  select count(*) into result_count
  from public.parcels p
  join public.orders o on o.id=p.order_id
  join public.customers c on c.id=o.customer_id
  left join lateral (
    select d.outcome, d.occurred_at from public.delivery_outcomes d
    where d.parcel_id=p.id order by d.occurred_at desc limit 1
  ) latest on true
  where o.notes='P14-T212 synthetic RTO load row' and p.state='RTO' and latest.outcome='RTO';
  elapsed_ms := extract(epoch from (clock_timestamp()-started))*1000;
  perform is(result_count,5000::bigint,'RTO operational query returns all 5,000 RTO parcels');
  perform ok(elapsed_ms < 5000,'RTO operational query completes within 5s characterization budget');
end $$;

do $$
declare
  started timestamptz;
  elapsed_ms numeric;
  result_count bigint;
begin
  started := clock_timestamp();
  select count(*) into result_count
  from (
    select p.state, count(*) parcel_count, count(d.id) outcome_count
    from public.parcels p
    join public.orders o on o.id=p.order_id
    left join public.delivery_outcomes d on d.parcel_id=p.id and d.outcome='RTO'
    where o.notes='P14-T212 synthetic RTO load row'
    group by p.state
  ) q;
  elapsed_ms := extract(epoch from (clock_timestamp()-started))*1000;
  perform is(result_count,1::bigint,'RTO summary returns one RTO state group');
  perform ok(elapsed_ms < 5000,'RTO summary aggregation completes within 5s characterization budget');
end $$;

select is((select count(*) from public.parcels p join public.orders o on o.id=p.order_id where o.notes='P14-T212 synthetic RTO load row'),5000::bigint,'RTO workload remains intact after read verification');

select * from finish();
rollback;
