-- P17 regression coverage for ambiguous RETURNS TABLE output-column references.
-- Read-only catalog assertions; no business data is inserted or modified.
BEGIN;
SELECT plan(14);

SELECT ok((SELECT count(*) = 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='allocate_cod_obligation_to_parcel'), 'COD allocation command exists exactly once');
SELECT ok((SELECT position('coa.cod_obligation_id = p_cod_obligation_id' IN lower(pg_get_functiondef(p.oid))) > 0 AND position('coa.parcel_id = p_parcel_id' IN lower(pg_get_functiondef(p.oid))) > 0 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='allocate_cod_obligation_to_parcel'), 'COD allocation predicates qualify both output-name collisions');
SELECT ok((SELECT position('where cod_obligation_id = p_cod_obligation_id' IN lower(pg_get_functiondef(p.oid))) = 0 AND position('and parcel_id = p_parcel_id' IN lower(pg_get_functiondef(p.oid))) = 0 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='allocate_cod_obligation_to_parcel'), 'unqualified COD allocation predicates are absent');

SELECT ok((SELECT count(*) = 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='cancel_parcel'), 'parcel cancellation command exists exactly once');
SELECT ok((SELECT position('where pi.parcel_id = p_parcel_id' IN lower(pg_get_functiondef(p.oid))) > 0 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='cancel_parcel'), 'parcel_items cancellation predicate is qualified');
SELECT ok((SELECT position('where parcel_id = p_parcel_id' IN lower(pg_get_functiondef(p.oid))) = 0 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='cancel_parcel'), 'unqualified parcel_id cancellation predicate is absent');

SELECT ok((SELECT position('where ir.batch_id = p_batch_id' IN lower(pg_get_functiondef(p.oid))) > 0 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='map_import_columns'), 'column-mapping row count qualifies batch_id');
SELECT ok((SELECT position('from public.import_rows where batch_id = p_batch_id' IN lower(pg_get_functiondef(p.oid))) = 0 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='map_import_columns'), 'unqualified column-mapping batch_id predicate is absent');

SELECT ok((SELECT position('where ir.batch_id = v_batch_id' IN lower(pg_get_functiondef(p.oid))) > 0 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='stage_import_file'), 'file-staging row count qualifies batch_id');
SELECT ok((SELECT position('from public.import_rows where batch_id = v_batch_id' IN lower(pg_get_functiondef(p.oid))) = 0 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='stage_import_file'), 'unqualified file-staging batch_id predicate is absent');

SELECT ok((SELECT bool_and(p.prosecdef) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('allocate_cod_obligation_to_parcel','cancel_parcel','map_import_columns','stage_import_file')), 'all four commands remain SECURITY DEFINER');
SELECT ok((SELECT bool_and('search_path=pg_catalog, public' = ANY(coalesce(p.proconfig,ARRAY[]::text[]))) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('allocate_cod_obligation_to_parcel','cancel_parcel','map_import_columns','stage_import_file')), 'all four commands retain the fixed search_path');
SELECT ok((SELECT count(*)=4 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('allocate_cod_obligation_to_parcel','cancel_parcel','map_import_columns','stage_import_file') AND position('#variable_conflict' IN lower(pg_get_functiondef(p.oid)))=0), 'no function uses #variable_conflict as a workaround');
SELECT ok((SELECT count(*)=4 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('allocate_cod_obligation_to_parcel','cancel_parcel','map_import_columns','stage_import_file')), 'all four targeted functions are present for regression coverage');

SELECT * FROM finish();
ROLLBACK;
