begin;

select plan(8);

select has_sequence('public', 'customer_code_seq', 'customer code sequence exists');
select has_sequence('public', 'order_number_seq', 'order number sequence exists');
select has_sequence('public', 'parcel_number_seq', 'parcel number sequence exists');

select has_column_default('public', 'customers', 'customer_code', $$('CUS-'::text || lpad((nextval('customer_code_seq'::regclass))::text, 6, '0'::text))$$, 'customer code uses sequence default');
select has_column_default('public', 'orders', 'order_number', $$('ORD-'::text || lpad((nextval('order_number_seq'::regclass))::text, 6, '0'::text))$$, 'order number uses sequence default');
select has_column_default('public', 'parcels', 'parcel_number', $$('PCL-'::text || lpad((nextval('parcel_number_seq'::regclass))::text, 6, '0'::text))$$, 'parcel number uses sequence default');

select ok(not has_sequence_privilege('anon', 'public.customer_code_seq', 'USAGE'), 'anon cannot directly consume customer sequence');
select ok(not has_sequence_privilege('authenticated', 'public.order_number_seq', 'USAGE'), 'authenticated cannot directly consume order sequence');

select * from finish();
rollback;
