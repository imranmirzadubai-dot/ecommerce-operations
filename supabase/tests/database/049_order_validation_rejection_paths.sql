begin;

-- P5-T102: order validation and confirmation rejection-path contract.
-- Verify every authoritative rejection has an explicit SQLSTATE/message and that
-- validation occurs before the Draft -> Confirmed mutation and event/audit writes.
select plan(17);

select ok(
  (select count(*) = 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='confirm_order'
     and pg_get_function_identity_arguments(p.oid)='p_order_id uuid, p_idempotency_key text'),
  'canonical confirm_order function is present'
);

select ok((select pg_get_functiondef(p.oid) like '%errcode=''42501''%Authenticated operational role required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'unauthenticated callers are rejected with 42501');

select ok((select pg_get_functiondef(p.oid) like '%errcode=''22023''%Order ID is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'null order ID is rejected with 22023');

select ok((select pg_get_functiondef(p.oid) like '%errcode=''22023''%Idempotency key is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'blank idempotency key is rejected with 22023');

select ok((select pg_get_functiondef(p.oid) like '%errcode=''P0002''%Order not found%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'unknown order is rejected with P0002');

select ok((select pg_get_functiondef(p.oid) like '%errcode=''P0001''%Only Draft orders can be confirmed%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'non-Draft orders are rejected with P0001');

select ok((select pg_get_functiondef(p.oid) like '%errcode=''P0001''%Order must have a customer before confirmation%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'orders without a customer are rejected with P0001');

select ok((select pg_get_functiondef(p.oid) like '%errcode=''P0001''%Order Total Order Amount must be zero or greater%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'null or negative order amounts are rejected with P0001');

select ok((select pg_get_functiondef(p.oid) like '%errcode=''P0001''%Order must contain at least one item%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'orders without items are rejected with P0001');

select ok((select pg_get_functiondef(p.oid) like '%errcode=''P0001''%Order contains an invalid item%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'invalid item description or quantity is rejected with P0001');

select ok((select position('select lifecycle_state,order_number,original_amount,customer_id' in pg_get_functiondef(p.oid)) < position('update public.orders' in pg_get_functiondef(p.oid))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'authoritative order validation precedes lifecycle mutation');

select ok((select position('select count(*) into v_item_count' in pg_get_functiondef(p.oid)) < position('update public.orders' in pg_get_functiondef(p.oid))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'item-count validation precedes lifecycle mutation');

select ok((select position('if exists (' in pg_get_functiondef(p.oid)) < position('update public.orders' in pg_get_functiondef(p.oid))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'item-content validation precedes lifecycle mutation');

select ok((select position('update public.orders' in pg_get_functiondef(p.oid)) < position('insert into public.order_events' in pg_get_functiondef(p.oid))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirmation event is emitted only after successful mutation');

select ok((select position('update public.orders' in pg_get_functiondef(p.oid)) < position('insert into public.audit_logs' in pg_get_functiondef(p.oid))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'audit record is written only after successful mutation');

select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''confirm_order''%' and position('claim_command_idempotency(' in pg_get_functiondef(p.oid)) < position('select lifecycle_state' in pg_get_functiondef(p.oid))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'idempotency is claimed before order validation/mutation');

select ok((select pg_get_functiondef(p.oid) like '%complete_command_idempotency(''confirm_order''%' and position('complete_command_idempotency(' in pg_get_functiondef(p.oid)) > position('insert into public.audit_logs' in pg_get_functiondef(p.oid))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'idempotency is completed only after successful confirmation and audit');

select * from finish();
rollback;
