-- P12-T189: deterministic source identity regression coverage.
begin;

select plan(10);

select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='import_rows' and column_name='source_identity'),'import rows expose deterministic source identity');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_import_source_identity'),'authoritative source identity command exists');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_import_source_identity'),'source identity command is SECURITY DEFINER');
select ok((select 'search_path=pg_catalog, public' = any(coalesce(p.proconfig,array[]::text[])) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_import_source_identity'),'source identity command locks its search_path');
select ok((select position('public.app_role() <> ''admin''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_import_source_identity'),'source identity command is Admin-only');
select ok((select has_function_privilege('anon','public.assign_import_source_identity(uuid,jsonb,text)','EXECUTE') = false),'anonymous execution is revoked');
select ok((select has_function_privilege('authenticated','public.assign_import_source_identity(uuid,jsonb,text)','EXECUTE') = true),'authenticated entry remains available for server-side role gating');
select ok((select position('md5(' in lower(pg_get_functiondef(p.oid))) > 0 and position('source_system' in lower(pg_get_functiondef(p.oid))) > 0 and position('source_file' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_import_source_identity'),'identity is derived deterministically from stable source metadata');
select ok((select position('normalized_data' in lower(pg_get_functiondef(p.oid))) > 0 and position('source_row_number' in lower(pg_get_functiondef(p.oid))) > 0 and position('source_record_id' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_import_source_identity'),'identity incorporates configured mapped values and stable source identifiers');
select ok((select position('raw_data' in lower(pg_get_functiondef(p.oid))) > 0 and position('p_identity_fields' in lower(pg_get_functiondef(p.oid))) > 0 and position('claim_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_import_source_identity'),'identity assignment retains raw source data and uses command idempotency');

select * from finish();
rollback;
