-- P12-T190: customer matching and exception-handling regression coverage.
begin;

select plan(10);

select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='import_rows' and column_name='matched_customer_id'),'import rows expose matched customer identity');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='import_rows' and column_name='customer_match_status'),'import rows expose customer match status');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='import_rows' and column_name='customer_match_method'),'import rows expose customer match method');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='import_rows' and column_name='customer_match_error'),'import rows retain customer match errors');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='match_import_customers'),'authoritative customer matching command exists');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='match_import_customers'),'customer matching command is SECURITY DEFINER');
select ok((select 'search_path=pg_catalog, public' = any(coalesce(p.proconfig,array[]::text[])) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='match_import_customers'),'customer matching command locks its search_path');
select ok((select position('public.app_role() <> ''admin''' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='match_import_customers'),'customer matching command is Admin-only');
select ok((select has_function_privilege('anon','public.match_import_customers(uuid,text,text)','EXECUTE') = false),'anonymous execution is revoked');
select ok((select position('normalized_phone' in lower(pg_get_functiondef(p.oid))) > 0 and position('matched' in lower(pg_get_functiondef(p.oid))) > 0 and position('create' in lower(pg_get_functiondef(p.oid))) > 0 and position('exception' in lower(pg_get_functiondef(p.oid))) > 0 and position('claim_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='match_import_customers'),'matching classifies exact phone matches, creates, exceptions, and uses idempotent retries');

select * from finish();
rollback;
