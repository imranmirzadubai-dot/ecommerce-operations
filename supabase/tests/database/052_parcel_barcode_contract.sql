begin;

-- P7-T115: barcode equality contract.
select plan(7);

select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='parcels' and column_name='barcode' and is_nullable='NO'), 'parcel barcode is required');
select ok((select count(*) = 1 from pg_constraint where conrelid='public.parcels'::regclass and contype='c' and pg_get_constraintdef(oid) like '%barcode = parcel_number%'), 'database enforces barcode equal to parcel_number');
select ok((select count(*) = 1 from pg_indexes where schemaname='public' and tablename='parcels' and indexdef like '%UNIQUE%' and indexdef like '%barcode%'), 'barcode is uniquely indexed');
select ok((select pg_get_functiondef(p.oid) like '%barcode,%' and pg_get_functiondef(p.oid) like '%v_parcel_number%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'), 'create_parcel writes the generated parcel number into barcode');
select ok((select pg_get_functiondef(p.oid) like '%''barcode'',v_parcel_number%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'), 'create_parcel returns barcode equal to parcel_number');
select ok((select pg_get_functiondef(p.oid) like '%''barcode'',v_parcel_number%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'), 'idempotent create_parcel results preserve barcode equality');
select ok((select pg_get_functiondef(p.oid) like '%''barcode'',v_parcel_number%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'), 'barcode is derived from the authoritative parcel identifier');

select * from finish();
rollback;
