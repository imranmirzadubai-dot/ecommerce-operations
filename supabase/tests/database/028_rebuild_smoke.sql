-- P3-T077: rebuild smoke checks.
-- The CI workflow creates an isolated local Supabase project, copies the
-- repository migrations and seed, runs `supabase db reset`, then executes
-- focused pgTAP tests. These assertions confirm the rebuilt schema is present.

begin;
select plan(8);

select ok((select count(*) = 17 from information_schema.tables where table_schema='public' and table_type='BASE TABLE' and table_name in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows')), 'rebuilt database contains all 17 application tables');
select ok((select count(*) = 3 from pg_sequences where schemaname='public' and sequencename in ('customer_code_seq','order_number_seq','parcel_number_seq')), 'rebuilt database contains all identifier sequences');
select ok((select count(*) = 17 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows') and c.relrowsecurity), 'rebuilt database has RLS enabled on all application tables');
select ok((select count(*) = 18 from pg_policies where schemaname='public' and tablename in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows') and cmd='SELECT'), 'rebuilt database has SELECT policy coverage including admin profile control');
select ok((select count(*) >= 7 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('create_order','confirm_order','cancel_order','cancel_parcel','claim_command_idempotency','complete_command_idempotency','resolve_customer_by_phone')), 'rebuilt database contains canonical transactional command functions');
select ok((select has_table_privilege('anon','public.orders','select') = false), 'rebuilt database denies anonymous direct table SELECT');
select ok((select has_table_privilege('authenticated','public.orders','select') and has_table_privilege('authenticated','public.orders','insert') = false and has_table_privilege('authenticated','public.orders','update') = false and has_table_privilege('authenticated','public.orders','delete') = false), 'rebuilt database preserves authenticated SELECT-only table access');
select ok((select count(*) = 0 from pg_policies where schemaname='public' and tablename in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows') and cmd in ('INSERT','UPDATE','DELETE')), 'rebuilt database has no direct-write RLS policies');

select * from finish();
rollback;
