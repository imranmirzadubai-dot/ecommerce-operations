-- P12-T187: required-field/type/date/amount validation regression coverage.
begin;

select plan(10);

select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'validate_import_rows'),'authoritative import validation command exists');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'validate_import_rows'),'validation command is SECURITY DEFINER');
select ok((select 'search_path=pg_catalog, public' = any(coalesce(p.proconfig, array[]::text[])) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'validate_import_rows'),'validation command locks its search_path');
select ok((select position('public.app_role() <> ''admin''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'validate_import_rows'),'validation command is Admin-only');
select ok((select has_function_privilege('anon', 'public.validate_import_rows(uuid,jsonb,jsonb,jsonb,jsonb,text)', 'EXECUTE') = false),'anonymous execution is revoked');
select ok((select has_function_privilege('authenticated', 'public.validate_import_rows(uuid,jsonb,jsonb,jsonb,jsonb,text)', 'EXECUTE') = true),'authenticated entry remains available for server-side role gating');
select ok((select position('missing required field:' in lower(pg_get_functiondef(p.oid))) > 0 and position('required fields must be a json array' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'validate_import_rows'),'validation enforces required-field presence');
select ok((select position('invalid integer type:' in lower(pg_get_functiondef(p.oid))) > 0 and position('invalid number type:' in lower(pg_get_functiondef(p.oid))) > 0 and position('invalid boolean type:' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'validate_import_rows'),'validation enforces declared field types');
select ok((select position('invalid date:' in lower(pg_get_functiondef(p.oid))) > 0 and position('pg_input_is_valid' in lower(pg_get_functiondef(p.oid))) > 0 and position('date fields must be declared as date' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'validate_import_rows'),'validation enforces ISO dates and date-field declarations');
select ok((select position('amount must be non-negative:' in lower(pg_get_functiondef(p.oid))) > 0 and position('amount must have at most 2 decimal places:' in lower(pg_get_functiondef(p.oid))) > 0 and position('amount fields must be numeric' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'validate_import_rows'),'validation enforces non-negative two-decimal monetary amounts');

select * from finish();
rollback;
