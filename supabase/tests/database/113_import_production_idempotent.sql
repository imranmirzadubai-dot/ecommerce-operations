-- P12-T194 static regression coverage for idempotent historical production import.
begin;

select plan(14);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch' and pg_get_function_identity_arguments(p.oid)='p_batch_id uuid, p_field_map jsonb, p_idempotency_key text'),'production import command exists with expected signature');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'production import is SECURITY DEFINER');
select ok((select 'search_path=pg_catalog, public'=any(coalesce(p.proconfig,array[]::text[])) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'production import uses fixed search_path');
select ok((select has_function_privilege('anon','public.import_historical_batch(uuid,jsonb,text)','EXECUTE')=false),'anon execution revoked');
select ok((select has_function_privilege('authenticated','public.import_historical_batch(uuid,jsonb,text)','EXECUTE')=true),'authenticated execution retained');
select ok((select position('public.app_role() <> ''admin''' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'production import is Admin-only');
select ok((select position('status <> ''Ready''' in pg_get_functiondef(p.oid))>0 and position('status=''Importing''' in pg_get_functiondef(p.oid))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'production import is gated to Ready and marks Importing');
select ok((select position('staging_reconciliation' in lower(pg_get_functiondef(p.oid)))>0 and position('monetary_count_reconciliation' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'both prior reconciliation results are required');
select ok((select position('claim_command_idempotency' in lower(pg_get_functiondef(p.oid)))>0 and position('complete_command_idempotency' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'command idempotency is implemented');
select ok((select position('on conflict (normalized_phone) do nothing' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'customer creation never overwrites an existing customer');
select ok((select position('insert into public.orders' in lower(pg_get_functiondef(p.oid)))>0 and position('insert into public.order_items' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'production import creates orders and order items');
select ok((select position('historical import' in lower(pg_get_functiondef(p.oid)))>0 and position('source_row_number' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'historical import event metadata identifies source row');
select ok((select position('lifecycle_state, currency_code, original_amount' in lower(pg_get_functiondef(p.oid)))>0 and position('''completed''' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'historical orders are inserted with authoritative amount and completed state');
select ok((select position('set status=''Completed''' in lower(pg_get_functiondef(p.oid)))>0 and position('completed_at=now()' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'successful batch is finalized atomically');

select * from finish();
rollback;
