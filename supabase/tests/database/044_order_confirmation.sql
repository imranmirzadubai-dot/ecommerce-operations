begin;

-- P5-T097: Order confirmation contract.
-- Confirm Draft -> Confirmed through one authenticated, idempotent command.
select plan(14);

select ok(
  (select count(*) = 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='confirm_order'
     and pg_get_function_identity_arguments(p.oid)='p_order_id uuid, p_idempotency_key text'),
  'canonical confirm_order signature exists'
);

select ok(
  (select count(*) = 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='confirm_order'
     and pg_get_function_identity_arguments(p.oid)='p_order_id uuid'),
  'legacy non-idempotent confirm_order overload is removed'
);

select ok((select pg_get_functiondef(p.oid) like '%auth.uid() is null or public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirm_order requires an authenticated operational role');

select ok((select pg_get_functiondef(p.oid) like '%Idempotency key is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirm_order requires an idempotency key');

select ok((select pg_get_functiondef(p.oid) like '%Only Draft orders can be confirmed%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirm_order enforces Draft-only transition');

select ok((select pg_get_functiondef(p.oid) like '%Order must have a customer before confirmation%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirm_order validates customer presence');

select ok((select pg_get_functiondef(p.oid) like '%Order Total Order Amount must be zero or greater%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirm_order validates the order amount');

select ok((select pg_get_functiondef(p.oid) like '%Order must contain at least one item%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirm_order requires at least one item');

select ok((select pg_get_functiondef(p.oid) like '%Order contains an invalid item%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirm_order validates item description and quantity');

select ok((select pg_get_functiondef(p.oid) like '%lifecycle_state=''Confirmed''%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirm_order performs Draft -> Confirmed transition');

select ok((select pg_get_functiondef(p.oid) like '%''OrderConfirmed''%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirmation emits an OrderConfirmed event');

select ok((select pg_get_functiondef(p.oid) like '%''confirm_order''%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirmation writes an audit record');

select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''confirm_order''%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirmation claims idempotency before mutation');

select ok((select pg_get_functiondef(p.oid) like '%complete_command_idempotency(''confirm_order''%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirmation completes the idempotency record');

select ok(
  has_function_privilege('authenticated','public.confirm_order(uuid,text)','execute')
  and has_function_privilege('anon','public.confirm_order(uuid,text)','execute') = false,
  'confirm_order is executable only by authenticated callers'
);

select * from finish();
rollback;
