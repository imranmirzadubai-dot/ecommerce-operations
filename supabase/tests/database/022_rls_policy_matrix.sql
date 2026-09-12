-- P3-T071 executable structural/security checks.
-- This file is safe to run against a staging database with pgTAP installed.

begin;

select plan(12);

select ok((select relrowsecurity from pg_class where oid='public.orders'::regclass), 'orders has RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.financial_adjustments'::regclass), 'financial_adjustments has RLS enabled');
select ok((select count(*) = 17 from pg_policies where schemaname='public' and tablename in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows')), 'all 17 application tables have one SELECT policy');
select ok((select count(*) = 0 from pg_policies where schemaname='public' and tablename in ('profiles','customers','shippers','orders','order_items','parcels','parcel_items','delivery_outcomes','cod_obligations','cod_obligation_allocations','cod_receipts','financial_adjustments','invoice_records','order_events','audit_logs','import_batches','import_rows') and cmd in ('INSERT','UPDATE','DELETE')), 'no direct write RLS policies exist');
select ok((select count(*) = 1 from pg_policies where schemaname='public' and tablename='financial_adjustments' and policyname='financial_adjustments_admin_select' and cmd='SELECT' and qual like '%app_role() = ''admin''%'), 'financial adjustments are Admin-read-only');
select ok((select count(*) = 1 from pg_policies where schemaname='public' and tablename='audit_logs' and policyname='audit_logs_admin_select'), 'audit logs are Admin-read-only');
select ok((select count(*) = 1 from pg_policies where schemaname='public' and tablename='import_batches' and policyname='import_batches_admin_select'), 'import batches are Admin-read-only');
select ok((select count(*) = 1 from pg_policies where schemaname='public' and tablename='import_rows' and policyname='import_rows_admin_select'), 'import rows are Admin-read-only');
select ok((select count(*) = 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_self_select' and qual like '%id = auth.uid()%'), 'profiles are self-read only');
select ok((select has_table_privilege('anon','public.orders','select') = false), 'anon has no direct orders SELECT privilege');
select ok((select has_table_privilege('authenticated','public.orders','select') and has_table_privilege('authenticated','public.orders','insert') = false and has_table_privilege('authenticated','public.orders','update') = false and has_table_privilege('authenticated','public.orders','delete') = false), 'authenticated orders access is SELECT-only');
select ok((select has_table_privilege('authenticated','public.financial_adjustments','select') and has_table_privilege('authenticated','public.financial_adjustments','insert') = false and has_table_privilege('authenticated','public.financial_adjustments','update') = false and has_table_privilege('authenticated','public.financial_adjustments','delete') = false), 'authenticated financial adjustments access is SELECT-only at grant layer');

select * from finish();
rollback;
