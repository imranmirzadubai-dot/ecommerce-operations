-- P3-T074: positive/negative RLS and grant-layer checks.
-- Designed for staging with pgTAP installed.

begin;
select plan(10);

select ok((select count(*) = 17 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows') and c.relrowsecurity), 'all 17 application tables have RLS enabled');
select ok((select count(*) = 17 from pg_policies where schemaname='public' and tablename in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows') and cmd='SELECT'), 'all application tables have SELECT policy coverage');
select ok((select count(*) = 0 from pg_policies where schemaname='public' and tablename in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows') and cmd in ('INSERT','UPDATE','DELETE')), 'negative: no direct write policies exist');
select ok((select has_table_privilege('anon','public.orders','select') = false), 'negative: anon cannot SELECT orders');
select ok((select has_table_privilege('authenticated','public.orders','insert') = false), 'negative: authenticated cannot INSERT orders');
select ok((select has_table_privilege('authenticated','public.orders','update') = false), 'negative: authenticated cannot UPDATE orders');
select ok((select has_table_privilege('authenticated','public.orders','delete') = false), 'negative: authenticated cannot DELETE orders');
select ok((select has_table_privilege('authenticated','public.orders','select') = true), 'positive: authenticated retains SELECT orders');
select ok((select count(*) = 1 from pg_policies where schemaname='public' and tablename='financial_adjustments' and policyname='financial_adjustments_admin_select'), 'positive: financial adjustments Admin SELECT policy exists');
select ok((select count(*) = 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_self_select'), 'positive: profile self SELECT policy exists');

select * from finish();
rollback;
