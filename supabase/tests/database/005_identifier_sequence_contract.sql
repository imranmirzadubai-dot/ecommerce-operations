begin;
set constraints all immediate;

select plan(12);

select has_function('public','generate_customer_code',ARRAY[]::text[],'customer code generator exists');
select has_function('public','generate_order_number',ARRAY[]::text[],'order number generator exists');
select has_function('public','generate_parcel_number',ARRAY[]::text[],'parcel number generator exists');
select ok(to_regclass('public.customer_code_seq') is not null,'customer code sequence exists');
select ok(to_regclass('public.order_number_seq') is not null,'order number sequence exists');
select ok(to_regclass('public.parcel_number_seq') is not null,'parcel number sequence exists');
select ok((select customer_code from public.customers limit 1) is null or (select customer_code from public.customers limit 1) ~ '^CUS-[0-9]{6,}$','customer code format is CUS-prefixed');
select ok((select order_number from public.orders limit 1) is null or (select order_number from public.orders limit 1) ~ '^ORD-[0-9]{6,}$','order number format is ORD-prefixed');
select ok((select parcel_number from public.parcels limit 1) is null or (select parcel_number from public.parcels limit 1) ~ '^PCL-[0-9]{6,}$','parcel number format is PCL-prefixed');
select ok((select count(*) from information_schema.columns where table_schema='public' and table_name='parcels' and column_name='barcode') = 1,'parcel barcode column exists');
select ok((select count(*) from pg_constraint c join pg_class t on t.oid=c.conrelid where t.oid='public.parcels'::regclass and c.contype='u') > 0,'parcel uniqueness constraints exist');
select ok((select count(*) from pg_constraint c join pg_class t on t.oid=c.conrelid where t.oid='public.orders'::regclass and c.contype='u') > 0,'order uniqueness constraints exist');

select * from finish();
rollback;
