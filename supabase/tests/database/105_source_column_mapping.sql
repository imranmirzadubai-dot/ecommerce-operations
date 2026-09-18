-- P12-T186: source-column mapping regression coverage.
begin;

select plan(10);

select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'map_import_columns'),'authoritative source-column mapping command exists');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'map_import_columns'),'mapping command is SECURITY DEFINER');
select ok((select 'search_path=pg_catalog, public' = any(coalesce(p.proconfig, array[]::text[])) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'map_import_columns'),'mapping command locks its search_path');
select ok((select position('public.app_role() <> ''admin''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'map_import_columns'),'mapping command is Admin-only');
select ok((select has_function_privilege('anon', 'public.map_import_columns(uuid,jsonb,text)', 'EXECUTE') = false),'anonymous execution is revoked');
select ok((select has_function_privilege('authenticated', 'public.map_import_columns(uuid,jsonb,text)', 'EXECUTE') = true),'authenticated entry remains available for server-side role gating');
select ok((select position('jsonb_typeof(p_mapping) <> ''object''' in lower(pg_get_functiondef(p.oid))) > 0 and position('jsonb_object_length(p_mapping) = 0' in lower(pg_get_functiondef(p.oid))) > 0 and position('column mapping target names must be unique' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'map_import_columns'),'mapping validates a non-empty object with unique target names');
select ok((select position('normalized_data = mapped.normalized_data' in lower(pg_get_functiondef(p.oid))) > 0 and position('jsonb_object_agg' in lower(pg_get_functiondef(p.oid))) > 0 and position('r2.raw_data -> m.key' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'map_import_columns'),'mapped source values are written into normalized_data');
select ok((select position('v_status <> ''uploaded''' in lower(pg_get_functiondef(p.oid))) > 0 and position('status = ''pending''' in lower(pg_get_functiondef(p.oid))) > 0 and position('set status = ''mapping''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'map_import_columns'),'mapping is allowed only from Uploaded batches and advances the batch to Mapping');
select ok((select position('claim_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0 and position('complete_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0 and position('not v_claim.is_new' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'map_import_columns'),'mapping retries are idempotent and return the existing batch result');

select * from finish();
rollback;
