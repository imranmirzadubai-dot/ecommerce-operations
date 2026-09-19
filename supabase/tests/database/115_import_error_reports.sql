-- P12-T196 regression coverage for deterministic historical import error reports.
begin;

select plan(10);

select ok((select count(*) = 1
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='generate_import_error_report'),
  'authoritative import error report command exists');

select ok((select p.prosecdef
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='generate_import_error_report'),
  'error report command is SECURITY DEFINER');

select ok((select 'search_path=pg_catalog, public' = any(coalesce(p.proconfig,array[]::text[]))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='generate_import_error_report'),
  'error report command locks its search_path');

select ok((select position('public.app_role() <> ''admin''' in lower(pg_get_functiondef(p.oid))) > 0
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='generate_import_error_report'),
  'error report command is Admin-only');

select ok((select has_function_privilege('anon','public.generate_import_error_report(uuid)','EXECUTE') = false),
  'anonymous execution is revoked');

select ok((select has_function_privilege('authenticated','public.generate_import_error_report(uuid)','EXECUTE') = true),
  'authenticated entry remains available for server-side role gating');

select ok((select position("status = 'Error'" in pg_get_functiondef(p.oid)) > 0
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='generate_import_error_report'),
  'report includes only retained error rows');

select ok((select position('source_row_number' in lower(pg_get_functiondef(p.oid))) > 0
              and position('source_record_id' in lower(pg_get_functiondef(p.oid))) > 0
              and position('source_identity' in lower(pg_get_functiondef(p.oid))) > 0
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='generate_import_error_report'),
  'report preserves source-row and deterministic source identity lineage');

select ok((select position('order by r.source_row_number' in lower(pg_get_functiondef(p.oid))) > 0
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='generate_import_error_report'),
  'report ordering is deterministic by source row');

select ok((select position('public.import_rows' in lower(pg_get_functiondef(p.oid))) > 0
              and position('r.error' in lower(pg_get_functiondef(p.oid))) > 0
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='generate_import_error_report'),
  'report is generated from authoritative retained import-row errors');

select * from finish();
rollback;
