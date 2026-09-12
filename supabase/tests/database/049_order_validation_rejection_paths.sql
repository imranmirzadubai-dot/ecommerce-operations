begin;

-- P5-T102: order validation and confirmation rejection-path contract.
-- Verify every authoritative rejection has an explicit SQLSTATE/message and that
-- validation occurs before the Draft -> Confirmed mutation and event/audit writes.
select plan(17);

do $$
declare
  v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public'
     and p.proname='confirm_order'
     and pg_get_function_identity_arguments(p.oid)='p_order_id uuid, p_idempotency_key text';

  perform ok(v_def is not null, 'canonical confirm_order function is present');
  perform ok(v_def like '%errcode=''42501''%Authenticated operational role required%', 'unauthenticated callers are rejected with 42501');
  perform ok(v_def like '%errcode=''22023''%Order ID is required%', 'null order ID is rejected with 22023');
  perform ok(v_def like '%errcode=''22023''%Idempotency key is required%', 'blank idempotency key is rejected with 22023');
  perform ok(v_def like '%errcode=''P0002''%Order not found%', 'unknown order is rejected with P0002');
  perform ok(v_def like '%errcode=''P0001''%Only Draft orders can be confirmed%', 'non-Draft orders are rejected with P0001');
  perform ok(v_def like '%errcode=''P0001''%Order must have a customer before confirmation%', 'orders without a customer are rejected with P0001');
  perform ok(v_def like '%errcode=''P0001''%Order Total Order Amount must be zero or greater%', 'null or negative order amounts are rejected with P0001');
  perform ok(v_def like '%errcode=''P0001''%Order must contain at least one item%', 'orders without items are rejected with P0001');
  perform ok(v_def like '%errcode=''P0001''%Order contains an invalid item%', 'invalid item description or quantity is rejected with P0001');
  perform ok(position('select lifecycle_state,order_number,original_amount,customer_id' in v_def) < position('update public.orders' in v_def), 'authoritative order validation precedes lifecycle mutation');
  perform ok(position('select count(*) into v_item_count' in v_def) < position('update public.orders' in v_def), 'item-count validation precedes lifecycle mutation');
  perform ok(position('if exists (' in v_def) < position('update public.orders' in v_def), 'item-content validation precedes lifecycle mutation');
  perform ok(position('update public.orders' in v_def) < position('insert into public.order_events' in v_def), 'confirmation event is emitted only after successful mutation');
  perform ok(position('update public.orders' in v_def) < position('insert into public.audit_logs' in v_def), 'audit record is written only after successful mutation');
  perform ok(v_def like '%claim_command_idempotency(''confirm_order''%' and position('claim_command_idempotency(' in v_def) < position('select lifecycle_state' in v_def), 'idempotency is claimed before order validation/mutation');
  perform ok(v_def like '%complete_command_idempotency(''confirm_order''%' and position('complete_command_idempotency(' in v_def) > position('insert into public.audit_logs' in v_def), 'idempotency is completed only after successful confirmation and audit');
end $$;

select * from finish();
rollback;
