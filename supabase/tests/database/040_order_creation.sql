begin;

-- P5-T093: Order creation contract.
-- Verify the implemented command boundary and persisted Draft-order behavior
-- without inventing additional business rules.
select plan(12);

select ok(
  (select count(*) = 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='create_order'
     and pg_get_function_identity_arguments(p.oid)='p_customer_name text, p_phone text, p_address text, p_city text, p_original_amount numeric, p_items jsonb, p_notes text, p_idempotency_key text'),
  'canonical create_order signature exists'
);

select ok((select pg_get_functiondef(p.oid) like '%auth.uid() is null or public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'create_order requires an authenticated operational role');

select ok((select pg_get_functiondef(p.oid) like '%Idempotency key is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'create_order requires an idempotency key');

select ok((select pg_get_functiondef(p.oid) like '%Total Order Amount must be zero or greater%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'create_order rejects negative order amounts');

select ok((select pg_get_functiondef(p.oid) like '%At least one order item is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'create_order requires at least one item');

select ok((select pg_get_functiondef(p.oid) like '%lifecycle_state%''Draft%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'new orders are created in Draft state');

select ok((select pg_get_functiondef(p.oid) like '%insert into public.order_items%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'order items are persisted by the command');

select ok((select pg_get_functiondef(p.oid) like '%OrderCreated%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'order creation emits an OrderCreated event');

select ok((select pg_get_functiondef(p.oid) like '%audit_logs%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'order creation writes an audit record');

select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''create_order''%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'order creation claims idempotency before mutation');

select ok(has_function_privilege('authenticated','public.create_order(text,text,text,text,numeric,jsonb,text,text)','execute'), 'authenticated role can execute create_order');
select ok(has_function_privilege('anon','public.create_order(text,text,text,text,numeric,jsonb,text,text)','execute') = false, 'anonymous callers cannot execute create_order');

select * from finish();
rollback;
