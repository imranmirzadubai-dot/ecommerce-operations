-- P3-T077: verify the database can be rebuilt from the repository migration chain.
-- This test is intentionally self-contained and validates the fresh local database
-- produced by `supabase db reset` in CI.

begin;
select plan(8);

select ok((select count(*) = 30 from supabase_migrations.schema_migrations), 'rebuild applied the complete repository migration chain');
select ok((select count(*) = 18 from information_schema.tables where table_schema='public' and table_type='BASE TABLE' and table_name in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows','command_idempotency')), 'all 18 application/foundation tables exist');
select ok((select count(*) = 3 from information_schema.sequences where sequence_schema='public' and sequence_name in ('customer_code_seq','order_number_seq','parcel_number_seq')), 'all 3 identifier sequences exist');
select ok((select count(*) = 17 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relrowsecurity and c.relname in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows')), 'all 17 application tables retain RLS');
select ok((select count(*) = 17 from pg_policies where schemaname='public' and tablename in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows') and cmd='SELECT'), 'all application SELECT policies exist');
select ok((select count(*) = 8 from (select p.proname, pg_get_function_identity_arguments(p.oid) args from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] and p.proname in ('app_role','create_order','confirm_order','cancel_order','cancel_parcel','claim_command_idempotency','complete_command_idempotency','resolve_customer_by_phone')) approved), 'all 8 approved SECURITY DEFINER application functions pin search_path');
select ok((select has_table_privilege('authenticated','public.orders','select') and not has_table_privilege('authenticated','public.orders','insert')), 'least-privilege table grants survive rebuild');
select ok((select has_table_privilege('anon','public.orders','select') = false and has_table_privilege('authenticated','public.financial_adjustments','update') = false), 'negative privilege boundaries survive rebuild');

select * from finish();
rollback;
