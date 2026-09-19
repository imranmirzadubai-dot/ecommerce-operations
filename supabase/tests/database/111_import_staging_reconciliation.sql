-- P12-T192 static regression coverage for staging reconciliation.
begin;

select plan(11);

select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'reconcile_import_staging' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'reconciliation command exists with expected signature');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'reconcile_import_staging' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'reconciliation command is SECURITY DEFINER');
select ok((select 'search_path=pg_catalog, public' = any(coalesce(p.proconfig,array[]::text[])) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'reconcile_import_staging' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'reconciliation command uses fixed search_path');
select ok((select has_function_privilege('anon','public.reconcile_import_staging(uuid,text)','EXECUTE') = false),'anon execution revoked');
select ok((select has_function_privilege('authenticated','public.reconcile_import_staging(uuid,text)','EXECUTE') = true),'authenticated execution retained');
select ok((select position('public.app_role() <> ''admin''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'reconcile_import_staging' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'reconciliation is Admin-only');
select ok((select position('reconciliation_summary' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'reconcile_import_staging' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'reconciliation persists batch summary');
select ok((select position('customer_match_status = ''matched''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'reconcile_import_staging' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'reconciliation counts matched rows');
select ok((select position('customer_match_status = ''create''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'reconcile_import_staging' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'reconciliation counts create rows');
select ok((select position('customer_match_status = ''exception''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'reconcile_import_staging' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'reconciliation counts exception rows');
select ok((select position('claim_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0 and position('complete_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'reconcile_import_staging' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'reconciliation uses command idempotency');

select * from finish();
rollback;
