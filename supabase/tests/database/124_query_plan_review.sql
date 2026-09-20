begin;

select plan(16);
set local role postgres;

-- P14-T213: deterministic query-plan review against a representative synthetic
-- workload. This is a CI/local database characterization, not production
-- capacity certification or a Cloudflare/Supabase control-plane benchmark.

insert into auth.users (id, aud, role, email, encrypted_password)
values ('00000000-0000-0000-0000-000000000330'::uuid, 'authenticated', 'authenticated', 'query-plan@example.test', 'test-only');
insert into public.profiles(id,name,email,role,active)
values ('00000000-0000-0000-0000-000000000330'::uuid,'Query Plan Test','query-plan@example.test','admin',true);

insert into public.customers(id,name,phone,normalized_phone,address,city)
select
  ('12000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  'Plan Customer ' || g,
  '052000' || lpad(g::text,6,'0'),
  '052000' || lpad(g::text,6,'0'),
  'Query Plan Test Address',
  case when g % 3 = 0 then 'Dubai' when g % 3 = 1 then 'Sharjah' else 'Ajman' end
from generate_series(1,5000) g;

insert into public.orders(id,customer_id,order_date,currency_code,original_amount,lifecycle_state,notes,created_by)
select
  ('22000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  ('12000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  current_date - ((g-1) % 30),
  'AED',
  (75 + (g % 400))::numeric(12,2),
  case when g % 5 = 0 then 'Cancelled' when g % 3 = 0 then 'Completed' when g % 2 = 0 then 'Confirmed' else 'Draft' end,
  'P14-T213 synthetic query plan row',
  '00000000-0000-0000-0000-000000000330'::uuid
from generate_series(1,5000) g;

insert into public.parcels(id,order_id,barcode,state,tracking_id)
select
  ('32000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  ('22000000-0000-0000-0000-' || lpad(g::text,12,'0'))::uuid,
  'P14T213-' || lpad(g::text,6,'0'),
  case when g % 4 = 0 then 'Dispatched' else 'Prepared' end,
  'TRK-P14T213-' || lpad(g::text,6,'0')
from generate_series(1,5000) g;

analyze public.customers;
analyze public.orders;
analyze public.parcels;

-- Index inventory is part of the query-plan contract and is verified directly.
select ok(exists(select 1 from pg_indexes where schemaname='public' and tablename='orders' and indexname='idx_orders_customer_id'),'orders customer_id index exists');
select ok(exists(select 1 from pg_indexes where schemaname='public' and tablename='orders' and indexname='idx_orders_order_date'),'orders order_date index exists');
select ok(exists(select 1 from pg_indexes where schemaname='public' and tablename='orders' and indexname='idx_orders_lifecycle_state'),'orders lifecycle_state index exists');
select ok(exists(select 1 from pg_indexes where schemaname='public' and tablename='parcels' and indexname='idx_parcels_order_id'),'parcels order_id index exists');
select ok(exists(select 1 from pg_indexes where schemaname='public' and tablename='parcels' and indexname='idx_parcels_state'),'parcels state index exists');
select ok(exists(select 1 from pg_indexes where schemaname='public' and tablename='parcels' and indexname='idx_parcels_tracking_id'),'parcels tracking_id index exists');
select ok(exists(select 1 from pg_indexes where schemaname='public' and tablename='delivery_outcomes' and indexname='idx_delivery_outcomes_parcel_id'),'delivery outcomes parcel_id index exists');

-- Capture actual analyzed plans for selective indexed lookups. PostgreSQL may
-- choose a different plan for broad scans; these assertions target queries where
-- the locked indexes are expected to be useful.
do $$
declare
  v_plan jsonb;
  v_text text;
  v_exec_ms numeric;
begin
  execute $$EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
    SELECT id, customer_id, order_date, lifecycle_state, original_amount
    FROM public.orders
    WHERE customer_id='12000000-0000-0000-0000-000000000330'::uuid$$ into v_plan;
  v_text := v_plan::text;
  v_exec_ms := (v_plan->0->>'Execution Time')::numeric;
  perform ok(v_text like '%Index Scan%' or v_text like '%Bitmap Index Scan%','orders customer lookup uses an indexed plan');
  perform ok(v_exec_ms < 5000,'orders customer lookup analyzed execution is under 5s');

  execute $$EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
    SELECT id, order_id, state, tracking_id
    FROM public.parcels
    WHERE tracking_id='TRK-P14T213-000001'$$ into v_plan;
  v_text := v_plan::text;
  v_exec_ms := (v_plan->0->>'Execution Time')::numeric;
  perform ok(v_text like '%Index Scan%' or v_text like '%Bitmap Index Scan%','parcel tracking lookup uses an indexed plan');
  perform ok(v_exec_ms < 5000,'parcel tracking lookup analyzed execution is under 5s');

  execute $$EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
    SELECT count(*)
    FROM public.orders o
    JOIN public.customers c ON c.id=o.customer_id
    WHERE o.order_date >= current_date - 6
      AND o.order_date <= current_date
      AND o.lifecycle_state in ('Draft','Confirmed','Completed')$$ into v_plan;
  v_exec_ms := (v_plan->0->>'Execution Time')::numeric;
  perform ok(v_exec_ms < 5000,'Orders reporting filter analyzed execution is under 5s');

  execute $$EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
    SELECT count(*)
    FROM public.parcels p
    JOIN public.orders o ON o.id=p.order_id
    WHERE p.state='Dispatched'$$ into v_plan;
  v_exec_ms := (v_plan->0->>'Execution Time')::numeric;
  perform ok(v_exec_ms < 5000,'parcel state reporting query analyzed execution is under 5s');
end $$;

select is((select count(*) from public.orders where notes='P14-T213 synthetic query plan row'),5000::bigint,'synthetic order workload remains intact');
select is((select count(*) from public.parcels p join public.orders o on o.id=p.order_id where o.notes='P14-T213 synthetic query plan row'),5000::bigint,'synthetic parcel workload remains intact');

select * from finish();
rollback;
