-- P12-T191 static regression coverage for import preview counts.
select plan(10);

select has_function('public', 'preview_import_customer_changes', ARRAY['uuid','text'], 'preview command exists');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'preview_import_customer_changes' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_idempotency_key text'),'preview command is SECURITY DEFINER');
select function_has_config_parameter('public', 'preview_import_customer_changes', ARRAY['uuid','text'], 'search_path = pg_catalog, public', 'preview command uses fixed search_path');
select function_has_privilege('anon', 'public.preview_import_customer_changes(uuid,text)', 'EXECUTE', false, 'anon execution revoked');
select function_has_privilege('authenticated', 'public.preview_import_customer_changes(uuid,text)', 'EXECUTE', true, 'authenticated execution retained');

select function_source_like('public', 'preview_import_customer_changes', ARRAY['uuid','text'], 'Admin role required', 'preview command is Admin-only');
select function_source_like('public', 'preview_import_customer_changes', ARRAY['uuid','text'], 'status = ''Create''', 'preview counts Create rows');
select function_source_like('public', 'preview_import_customer_changes', ARRAY['uuid','text'], 'status = ''Matched''', 'preview counts Matched rows as updates');
select function_source_like('public', 'preview_import_customer_changes', ARRAY['uuid','text'], 'status in (''Error'',''Exception'')', 'preview counts error rows');
select function_source_like('public', 'preview_import_customer_changes', ARRAY['uuid','text'], 'claim_command_idempotency', 'preview uses command idempotency');

select * from finish();
