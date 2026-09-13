begin;

-- P5-T096: Pre-confirmation Draft Order editing contract.
select plan(16);

select ok(
  (select count(*) = 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='update_order'
     and pg_get_function_identity_arguments(p.oid)='p_order_id uuid, p_customer_name text, p_phone text, p_address text, p_city text, p_original_amount numeric, p_items jsonb, p_notes text, p_idempotency_key text'),
  'canonical update_order signature exists'
);

select ok((select pg_get_functiondef(p.oid) like '%auth.uid() is null or public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'update_order requires an authenticated operational role');

select ok((select pg_get_functiondef(p.oid) like '%Idempotency key is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'update_order requires an idempotency key');

select ok((select pg_get_functiondef(p.oid) like '%Order ID is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'update_order requires an order ID');

select ok((select pg_get_functiondef(p.oid) like '%Customer name is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'update_order validates customer name');

select ok((select pg_get_functiondef(p.oid) like '%Customer phone is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'update_order validates customer phone');

select ok((select pg_get_functiondef(p.oid) like '%Total Order Amount must be zero or greater%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'update_order rejects negative order amounts');

select ok((select pg_get_functiondef(p.oid) like '%At least one order item is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'update_order requires at least one item');

select ok((select pg_get_functiondef(p.oid) like '%if v_state <> ''Draft'' then%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'update_order is restricted to Draft orders');

select ok((select pg_get_functiondef(p.oid) like '%Only Draft orders can be edited before confirmation%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'non-Draft edits are rejected by the command');

select ok((select pg_get_functiondef(p.oid) like '%delete from public.order_items where order_id=p_order_id%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'Draft item set is replaced atomically');

select ok((select pg_get_functiondef(p.oid) like '%insert into public.order_items(order_id,line_no,description,quantity)%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'updated items are persisted with deterministic line numbers');

select ok((select pg_get_functiondef(p.oid) like '%OrderUpdated%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'Draft editing emits an OrderUpdated event');

select ok((select pg_get_functiondef(p.oid) like '%audit_logs%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='update_order'), 'Draft editing writes an audit record');

select ok(has_function_privilege('authenticated','public.update_order(uuid,text,text,text,text,numeric,jsonb,text,text)','execute'), 'authenticated role can execute update_order');
select ok(has_function_privilege('anon','public.update_order(uuid,text,text,text,text,numeric,jsonb,text,text)','execute') = false, 'anonymous callers cannot execute update_order');

select * from finish();
rollback;
