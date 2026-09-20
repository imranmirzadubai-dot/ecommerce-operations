begin;

select plan(8);
set local role postgres;

-- Synthetic, rollback-scoped workload. This is an application-database load
-- characterization test, not a production load test. It creates 5,000 orders,
-- one customer and one item per order, exercises representative Orders queries,
-- and removes everything on rollback.

create temporary table load_actor(id uuid primary key);
insert into auth.users (id, aud, role, email, encrypted_password)
values ('00000000-0000-0000-0000-000000000310'::uuid, 'authenticated', 'authenticated', 'orders-load@example.test', 'test-only');
insert into public.profiles(id,name,email,role,active)
values ('00000000-0000-0000-0000-000000000310'::uuid,'Orders Load Test','orders-load@example.test','admin',true);
insert into load_actor values ('00000000-0000-0000-0000-000000000310'::uuid);

-- 5,000 synthetic customers and orders, distributed over 30 calendar days.
insert into public.customers(id,name,phone,normalized_phone,address,city)
select
  ('10000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  'Load Customer ' || g,
  '050000' || lpad(g::text,6,'0'),
  '050000' || lpad(g::text,6,'0'),
  'Load Test Address',
  case when g % 3 = 0 then 'Dubai' when g % 3 = 1 then 'Sharjah' else 'Ajman' end
from generate_series(1,5000) g;

insert into public.orders(id,customer_id,order_date,currency_code,original_amount,lifecycle_state,notes,created_by)
select
  ('20000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  ('10000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  current_date - ((g-1) % 30),
  'AED',
  (50 + (g % 450))::numeric(12,2),
  case when g % 5 = 0 then 'Cancelled' when g % 3 = 0 then 'Completed' when g % 2 = 0 then 'Confirmed' else 'Draft' end,
  'P14-T210 synthetic load row',
  '00000000-0000-0000-0000-000000000310'::uuid
from generate_series(1,5000) g;

insert into public.order_items(id,order_id,line_no,description,quantity)
select
  ('30000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  ('20000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  1,
  'Load Test Item ' || g,
  1 + (g % 4)
from generate_series(1,5000) g;

select is((select count(*) from public.orders where notes='P14-T210 synthetic load row'),5000::bigint,'5,000 synthetic orders loaded');
select is((select count(*) from public.order_items oi join public.orders o on o.id=oi.order_id where o.notes='P14-T210 synthetic load row'),5000::bigint,'5,000 order items loaded');

-- Orders workspace-style filtered listing: date + lifecycle, joined to customer.
declare
  started timestamptz;
  elapsed_ms numeric;
  result_count bigint;
begin
  started := clock_timestamp();
  select count(*) into result_count
  from public.orders o
  join public.customers c on c.id=o.customer_id
  where o.notes='P14-T210 synthetic load row'
    and o.order_date >= current_date - 6
    and o.order_date <= current_date
    and o.lifecycle_state in ('Draft','Confirmed','Completed');
  elapsed_ms := extract(epoch from (clock_timestamp()-started))*1000;
  perform ok(result_count > 0,'filtered Orders query returns rows under load');
  perform ok(elapsed_ms < 5000,'filtered Orders query completes within 5s on 5,000 synthetic orders');
end;

-- Orders workspace-style lifecycle summary.
declare
  started timestamptz;
  elapsed_ms numeric;
  result_count bigint;
begin
  started := clock_timestamp();
  select count(*) into result_count
  from (
    select o.lifecycle_state, count(*) order_count, sum(o.original_amount) original_amount_total
    from public.orders o
    where o.notes='P14-T210 synthetic load row'
    group by o.lifecycle_state
  ) q;
  elapsed_ms := extract(epoch from (clock_timestamp()-started))*1000;
  perform is(result_count,5::bigint,'lifecycle summary returns all five lifecycle states');
  perform ok(elapsed_ms < 5000,'lifecycle summary completes within 5s on 5,000 synthetic orders');
end;

-- Customer activity-style aggregation used by Phase 13 reporting.
declare
  started timestamptz;
  elapsed_ms numeric;
  result_count bigint;
begin
  started := clock_timestamp();
  select count(*) into result_count
  from (
    select c.id, count(o.id) order_count, sum(o.original_amount) original_amount_total
    from public.customers c
    join public.orders o on o.customer_id=c.id
    where o.notes='P14-T210 synthetic load row'
    group by c.id
  ) q;
  elapsed_ms := extract(epoch from (clock_timestamp()-started))*1000;
  perform is(result_count,5000::bigint,'customer activity aggregation returns all 5,000 customers');
  perform ok(elapsed_ms < 5000,'customer activity aggregation completes within 5s on 5,000 synthetic orders');
end;

select is((select count(*) from public.orders where notes='P14-T210 synthetic load row'),5000::bigint,'load dataset remains intact after read workload');

select * from finish();
rollback;
