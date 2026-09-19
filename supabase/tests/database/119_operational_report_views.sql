-- P13-T201: Operational report view contract tests.

select plan(42);

select has_view('public', 'report_orders', 'orders report view exists');
select has_view('public', 'report_parcel_delivery', 'parcel delivery report view exists');
select has_view('public', 'report_customer_activity', 'customer activity report view exists');

select has_column('public', 'report_orders', 'order_id', 'orders report exposes order id');
select has_column('public', 'report_orders', 'order_number', 'orders report exposes order number');
select has_column('public', 'report_orders', 'order_date', 'orders report exposes order date');
select has_column('public', 'report_orders', 'customer_code', 'orders report exposes customer code');
select has_column('public', 'report_orders', 'customer_name', 'orders report exposes customer name');
select has_column('public', 'report_orders', 'city', 'orders report exposes city');
select has_column('public', 'report_orders', 'original_amount', 'orders report exposes immutable original amount');
select has_column('public', 'report_orders', 'lifecycle_state', 'orders report exposes lifecycle state');
select has_column('public', 'report_orders', 'parcel_count', 'orders report exposes parcel count');
select has_column('public', 'report_orders', 'delivered_parcel_count', 'orders report exposes delivered count');
select has_column('public', 'report_orders', 'rto_parcel_count', 'orders report exposes RTO count');
select has_column('public', 'report_orders', 'lost_parcel_count', 'orders report exposes lost count');
select has_column('public', 'report_orders', 'damaged_parcel_count', 'orders report exposes damaged count');

select has_column('public', 'report_parcel_delivery', 'parcel_number', 'parcel report exposes parcel number');
select has_column('public', 'report_parcel_delivery', 'barcode', 'parcel report exposes barcode');
select has_column('public', 'report_parcel_delivery', 'order_number', 'parcel report exposes order number');
select has_column('public', 'report_parcel_delivery', 'parcel_state', 'parcel report exposes physical state');
select has_column('public', 'report_parcel_delivery', 'shipper_name', 'parcel report exposes shipper');
select has_column('public', 'report_parcel_delivery', 'tracking_id', 'parcel report exposes tracking id');
select has_column('public', 'report_parcel_delivery', 'dispatch_at', 'parcel report exposes dispatch timestamp');
select has_column('public', 'report_parcel_delivery', 'latest_outcome', 'parcel report exposes latest delivery outcome');
select has_column('public', 'report_parcel_delivery', 'latest_outcome_at', 'parcel report exposes latest outcome timestamp');
select has_column('public', 'report_parcel_delivery', 'delivered_amount', 'parcel report exposes collected amount');

select has_column('public', 'report_customer_activity', 'customer_code', 'customer report exposes customer code');
select has_column('public', 'report_customer_activity', 'normalized_phone', 'customer report exposes normalized phone');
select has_column('public', 'report_customer_activity', 'order_count', 'customer report exposes order count');
select has_column('public', 'report_customer_activity', 'first_order_date', 'customer report exposes first order date');
select has_column('public', 'report_customer_activity', 'latest_order_date', 'customer report exposes latest order date');
select has_column('public', 'report_customer_activity', 'original_order_amount_total', 'customer report exposes original order amount total');
select has_column('public', 'report_customer_activity', 'current_open_order_count', 'customer report exposes current open order count');

select is((select relrowsecurity from pg_class where oid = 'public.report_orders'::regclass), false, 'orders report is a view without table RLS');
select is((select has_table_privilege('anon', 'public.report_orders', 'select')), false, 'anonymous cannot select orders report');
select is((select has_table_privilege('anon', 'public.report_parcel_delivery', 'select')), false, 'anonymous cannot select parcel report');
select is((select has_table_privilege('anon', 'public.report_customer_activity', 'select')), false, 'anonymous cannot select customer report');
select is((select has_table_privilege('authenticated', 'public.report_orders', 'select')), true, 'authenticated can select orders report');
select is((select has_table_privilege('authenticated', 'public.report_parcel_delivery', 'select')), true, 'authenticated can select parcel report');
select is((select has_table_privilege('authenticated', 'public.report_customer_activity', 'select')), true, 'authenticated can select customer report');

select * from finish();
