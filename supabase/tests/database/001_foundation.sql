begin;

select plan(18);

select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'customers', 'customers table exists');
select has_table('public', 'orders', 'orders table exists');
select has_table('public', 'order_items', 'order_items table exists');
select has_table('public', 'parcels', 'parcels table exists');
select has_table('public', 'parcel_items', 'parcel_items table exists');
select has_table('public', 'delivery_outcomes', 'delivery_outcomes table exists');
select has_table('public', 'cod_obligations', 'cod_obligations table exists');
select has_table('public', 'cod_receipts', 'cod_receipts table exists');
select has_table('public', 'financial_adjustments', 'financial_adjustments table exists');
select has_table('public', 'invoice_records', 'invoice_records table exists');
select has_table('public', 'order_events', 'order_events table exists');
select has_table('public', 'audit_logs', 'audit_logs table exists');
select has_table('public', 'import_batches', 'import_batches table exists');
select has_table('public', 'import_rows', 'import_rows table exists');

select ok((select relrowsecurity from pg_class where oid = 'public.customers'::regclass), 'customers has RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.orders'::regclass), 'orders has RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.audit_logs'::regclass), 'audit_logs has RLS enabled');

select * from finish();
rollback;
