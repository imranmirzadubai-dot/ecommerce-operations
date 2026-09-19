-- P12-T197: rehearsal gate for the complete historical migration path.
-- This is a non-production CI rehearsal contract: it verifies that every required
-- stage is present, ordered, protected, and connected to the final import/lineage
-- controls. CI runs against a rebuilt local Supabase database only.
begin;

select plan(18);

select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='stage_import_file'),'rehearsal has the authoritative staging entry point');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='map_import_columns'),'rehearsal has the authoritative mapping entry point');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='validate_import_rows'),'rehearsal has the authoritative validation entry point');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='normalize_import_phone_fields'),'rehearsal has the authoritative phone-normalization entry point');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='assign_import_source_identity'),'rehearsal has the authoritative source-identity entry point');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='match_import_customers'),'rehearsal has the authoritative customer-matching entry point');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='preview_import_customer_changes'),'rehearsal has the preview gate');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='reconcile_import_staging'),'rehearsal has the staging-reconciliation gate');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='reconcile_import_monetary_counts'),'rehearsal has the monetary/count reconciliation gate');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'rehearsal has the production-import entry point');
select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='generate_import_error_report'),'rehearsal has the retained-error reporting entry point');
select ok((select count(*) = 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_events' and t.tgname='trg_retain_historical_import_lineage'),'rehearsal has the source-lineage retention trigger');

select ok((select position('status <> ''Ready''' in lower(pg_get_functiondef(p.oid))) > 0 and position('staging_reconciliation' in lower(pg_get_functiondef(p.oid))) > 0 and position('monetary_count_reconciliation' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'production import is blocked until Ready plus both reconciliations are satisfied');
select ok((select position('historical import' in lower(pg_get_functiondef(p.oid))) > 0 and position('source_row_number' in lower(pg_get_functiondef(p.oid))) > 0 and position('source_identity' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'production import emits source-lineage metadata for every imported row');
select ok((select position('insert into public.orders' in lower(pg_get_functiondef(p.oid))) > 0 and position('original_amount' in lower(pg_get_functiondef(p.oid))) > 0 and position('''completed''' in lower(pg_get_functiondef(p.oid))) > 0 and position('insert into public.order_items' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'rehearsal verifies historical orders preserve authoritative amount and create one order item per source row');
select ok((select position('status = ''Imported''' in lower(pg_get_functiondef(p.oid))) > 0 and position('historical_import_batch_id' in lower(pg_get_functiondef(p.oid))) > 0 and position('historical_import_source_identity' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='retain_historical_import_lineage'),'successful lineage retention marks the staged source row Imported and persists order lineage');
select ok((select position('claim_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0 and position('complete_command_idempotency' in lower(pg_get_functiondef(p.oid))) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'rehearsal verifies production import retries are idempotent');
select ok((select position('insert into public.parcels' in lower(pg_get_functiondef(p.oid))) = 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='import_historical_batch'),'rehearsal verifies historical import does not create parcel allocation');

select * from finish();
rollback;
