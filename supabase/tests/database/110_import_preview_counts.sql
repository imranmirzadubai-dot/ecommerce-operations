-- P12-T191 static regression coverage for import preview counts.
begin;

select plan(10);

select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'preview_import_customer_changes' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'preview command exists with expected signature');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'preview_import_customer_changes' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'preview command is SECURITY DEFINER');
select ok((select 'search_path=pg_catalog, public' = any(coalesce(p.proconfig,array[]::text[])) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'preview_import_customer_changes' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'preview command uses fixed search_path');
select ok((select has_function_privilege('anon','public.preview_import_customer_changes(uuid,text)','EXECUTE') = false),'anon execution revoked');
select ok((select has_function_privilege('authenticated','public.preview_import_customer_changes(uuid,text)','EXECUTE') = true),'authenticated execution retained');

select ok((select position('public.app_role() <> ''admin''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'preview_import_customer_changes' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'preview command is Admin-only');
select ok((select position('status = ''create''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'preview_import_customer_changes' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'preview counts Create rows');
select ok((select position('status = ''matched''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'preview_import_customer_changes' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'preview counts Matched rows as updates');
select ok((select position('status in (''error'',''exception'')' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'preview_import_customer_changes' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'preview counts error rows');
select ok((select position('claim_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0 and position('complete_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'preview_import_customer_changes' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'preview uses command idempotency');

select * from finish();
rollback;
