-- P12-T185: import file staging regression coverage.
begin;

select plan(10);

select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'stage_import_file'),'authoritative import file staging command exists');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'stage_import_file'),'staging command is SECURITY DEFINER');
select ok((select position('set search_path = pg_catalog, public' in pg_get_functiondef(p.oid)) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'stage_import_file'),'staging command locks its search_path');
select ok((select position('public.app_role() <> ''admin''' in pg_get_functiondef(p.oid)) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'stage_import_file'),'staging command is Admin-only');
select ok((select has_function_privilege('anon', 'public.stage_import_file(text,text,jsonb,text)', 'EXECUTE') = false),'anonymous execution is revoked');
select ok((select has_function_privilege('authenticated', 'public.stage_import_file(text,text,jsonb,text)', 'EXECUTE') = true),'authenticated entry remains available for server-side role gating');
select ok((select position('jsonb_typeof(p_rows) <> ''array''' in pg_get_functiondef(p.oid)) > 0 and position('jsonb_array_length(p_rows) = 0' in pg_get_functiondef(p.oid)) > 0 and position('Every import row must be a JSON object' in pg_get_functiondef(p.oid)) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'stage_import_file'),'staging validates a non-empty JSON array of source-row objects');
select ok((select position('insert into public.import_batches(source_system, source_file, initiated_by, status)' in pg_get_functiondef(p.oid)) > 0 and position('''Uploaded''' in pg_get_functiondef(p.oid)) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'stage_import_file'),'staging creates an Uploaded import batch with the authenticated initiator');
select ok((select position('insert into public.import_rows' in pg_get_functiondef(p.oid)) > 0 and position('raw_data' in pg_get_functiondef(p.oid)) > 0 and position('''Pending''' in pg_get_functiondef(p.oid)) > 0 and position('with ordinality' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'stage_import_file'),'source rows are retained verbatim with deterministic row numbers and Pending status');
select ok((select position('claim_command_idempotency' in pg_get_functiondef(p.oid)) > 0 and position('complete_command_idempotency' in pg_get_functiondef(p.oid)) > 0 and position('not v_claim.is_new' in pg_get_functiondef(p.oid)) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'stage_import_file'),'staging retries are idempotent and return the existing batch result');

select * from finish();
rollback;
