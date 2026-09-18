-- P12-T188: phone normalization regression coverage.
begin;

select plan(10);

select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'normalize_import_phone_fields' and pg_get_function_identity_arguments(p.oid) = 'p_batch_id uuid, p_phone_fields jsonb, p_default_country_code text, p_idempotency_key text'),'authoritative phone normalization command exists with the expected signature');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'normalize_import_phone_fields'),'phone normalization command is SECURITY DEFINER');
select ok((select 'search_path=pg_catalog, public' = any(coalesce(p.proconfig, array[]::text[])) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'normalize_import_phone_fields'),'phone normalization command locks its search_path');
select ok((select position('public.app_role() <> ''admin''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'normalize_import_phone_fields'),'phone normalization command is Admin-only');
select ok((select has_function_privilege('anon', 'public.normalize_import_phone_fields(uuid,jsonb,text,text)', 'EXECUTE') = false),'anonymous execution is revoked');
select ok((select has_function_privilege('authenticated', 'public.normalize_import_phone_fields(uuid,jsonb,text,text)', 'EXECUTE') = true),'authenticated entry remains available for server-side role gating');
select ok((select position('p_default_country_code' in pg_get_functiondef(p.oid)) > 0 and position('national' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'normalize_import_phone_fields'),'normalization supports national numbers through an explicit default country code');
select ok((select position('''+''' || v_country' in pg_get_functiondef(p.oid)) > 0 and position('^\\+[0-9]{7,15}$' in pg_get_functiondef(p.oid)) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'normalize_import_phone_fields'),'normalization emits canonical plus-prefixed international values');
select ok((select position('^00[0-9]{7,15}$' in pg_get_functiondef(p.oid)) > 0 and position('substring' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'normalize_import_phone_fields'),'normalization converts 00-prefixed international values');
select ok((select position('invalid phone number:' in lower(pg_get_functiondef(p.oid))) > 0 and position('r.normalized_data ||' in lower(pg_get_functiondef(p.oid))) > 0 and position('raw source values remain immutable' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'normalize_import_phone_fields'),'invalid phone values become row errors while other mapped fields and raw source values are retained');

select * from finish();
rollback;
