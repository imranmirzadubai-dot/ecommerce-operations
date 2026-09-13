begin;

select plan(11);

select has_function('public','create_order',ARRAY['text','text','text','text','numeric','jsonb','text','text'],'create_order canonical command exists');
select has_function('public','confirm_order',ARRAY['uuid','text'],'confirm_order canonical command exists');
select has_function('public','cancel_order',ARRAY['uuid','text'],'cancel_order canonical command exists');
select has_function('public','cancel_parcel',ARRAY['uuid','text'],'cancel_parcel canonical command exists');
select has_function('public','resolve_customer_by_phone',ARRAY['text'],'customer resolution command exists');
select has_function('public','claim_command_idempotency',ARRAY['text','text','text'],'idempotency claim command exists');
select has_function('public','complete_command_idempotency',ARRAY['text','text','jsonb'],'idempotency completion command exists');

select ok((select count(*)=7 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in ('create_order','confirm_order','cancel_order','cancel_parcel','resolve_customer_by_phone','claim_command_idempotency','complete_command_idempotency')
    and p.prosecdef), 'all protected commands are SECURITY DEFINER');

select ok((select count(*)=7 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in ('create_order','confirm_order','cancel_order','cancel_parcel','resolve_customer_by_phone','claim_command_idempotency','complete_command_idempotency')
    and has_function_privilege('anon',p.oid,'EXECUTE')=false
    and has_function_privilege('authenticated',p.oid,'EXECUTE')), 'all protected commands are callable only by authenticated role at SQL grant boundary');

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='cancel_order' and p.proargnames=array['p_order_id','p_idempotency_key']), 'cancel_order explicitly enforces the approved application-role set');

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='cancel_parcel' and p.proargnames=array['p_parcel_id','p_idempotency_key']), 'cancel_parcel explicitly enforces the approved application-role set');

select ok((select count(*)=0 from information_schema.role_table_grants
  where grantee in ('anon','authenticated') and table_schema='public'
    and privilege_type in ('INSERT','UPDATE','DELETE')
    and table_name in ('profiles','customers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows')),
  'browser roles retain no direct write privileges on protected application tables');

select * from finish();
rollback;
