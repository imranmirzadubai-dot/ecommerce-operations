-- P17-T295: courier/shippers model contract.
begin;

select plan(10);

select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='courier_code'),'shippers has courier_code');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='contact_name'),'shippers has contact_name');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='contact_phone'),'shippers has contact_phone');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='contact_email'),'shippers has contact_email');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='address'),'shippers has address');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='notes'),'shippers has notes');
select ok((select is_nullable = 'NO' from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='courier_code'),'courier_code is required');
select ok((select count(*) = 1 from pg_indexes where schemaname='public' and tablename='shippers' and indexname='uq_shippers_courier_code'),'courier_code is uniquely indexed');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='shippers'),'shippers RLS remains enabled');
select ok((select count(*) = 1 from pg_constraint c join pg_class t on t.oid=c.conrelid join pg_namespace n on n.oid=t.relnamespace where n.nspname='public' and t.relname='parcels' and c.conname='parcels_shipper_id_fkey'),'parcel-level shipper relationship remains present');

select * from finish();
rollback;
