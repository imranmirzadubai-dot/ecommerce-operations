begin;

-- P5-T095: Manual Total Order Amount contract.
-- The MVP uses one order-level AED amount. It is stored as NUMERIC(12,2),
-- supplied explicitly by Sales, and is not derived from order-item values.
select plan(9);

select ok(
  (select data_type = 'numeric' and numeric_precision = 12 and numeric_scale = 2
   from information_schema.columns
   where table_schema='public' and table_name='orders' and column_name='original_amount'),
  'orders.original_amount is NUMERIC(12,2)'
);

select ok(
  (select pg_get_function_arguments(p.oid) like '%p_original_amount numeric%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='create_order'),
  'create_order accepts a numeric Total Order Amount argument'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%if p_original_amount is null or p_original_amount<0 then%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='create_order'),
  'create_order rejects a missing or negative Total Order Amount'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%insert into public.orders(customer_id,original_amount,lifecycle_state,notes,created_by)%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='create_order'),
  'create_order persists the manually supplied amount at order level'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%original_amount'',p_original_amount%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='create_order'),
  'create_order audit data records the supplied original amount'
);

select ok(
  (select pg_get_functiondef(p.oid) not like '%unit_price%' and pg_get_functiondef(p.oid) not like '%service_fee%' and pg_get_functiondef(p.oid) not like '%discount%' and pg_get_functiondef(p.oid) not like '%vat%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='create_order'),
  'create_order does not introduce excluded item-price or fee fields'
);

select ok(
  (select has_function_privilege('authenticated','public.create_order(text,text,text,text,numeric,jsonb,text,text)','execute')),
  'authenticated operational users retain the create_order command boundary'
);

select ok(('100.50'::numeric(12,2)) = 100.50::numeric, 'AED values preserve two-decimal numeric precision');
select ok(('9999999999.99'::numeric(12,2)) = 9999999999.99::numeric, 'NUMERIC(12,2) supports the MVP column maximum');

select * from finish();
rollback;
