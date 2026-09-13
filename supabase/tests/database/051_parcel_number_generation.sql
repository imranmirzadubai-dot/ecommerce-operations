begin;

-- P7-T114: parcel number generation contract.
select plan(8);

select ok((select count(*) = 1 from information_schema.sequences where sequence_schema='public' and sequence_name='parcel_number_seq'), 'parcel number sequence exists');
select ok((select c.cycle = false from pg_sequences c where c.schemaname='public' and c.sequencename='parcel_number_seq'), 'parcel number sequence does not cycle');
select ok((select has_sequence_privilege('anon','public.parcel_number_seq','USAGE') = false and has_sequence_privilege('authenticated','public.parcel_number_seq','USAGE') = false), 'parcel number sequence is not directly exposed to browser roles');
select ok((select column_default like '%nextval(''public.parcel_number_seq''::regclass)%' from information_schema.columns where table_schema='public' and table_name='parcels' and column_name='parcel_number'), 'parcels have an authoritative sequence-backed parcel_number default');
select ok((select pg_get_functiondef(p.oid) like '%nextval(''public.parcel_number_seq'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'), 'create_parcel consumes the authoritative parcel number sequence');
select ok((select pg_get_functiondef(p.oid) like '%v_parcel_number:=''PCL-'' || lpad(nextval(''public.parcel_number_seq'')::text,6,''0'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'), 'create_parcel emits the PCL-XXXXXX parcel number format');
select ok((select pg_get_functiondef(p.oid) like '%parcel_number%' and pg_get_functiondef(p.oid) like '%unique%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'), 'parcel creation targets the unique parcel_number column');
select ok((select pg_get_functiondef(p.oid) like '%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'), 'parcel creation serializes the source order before mutation');

select * from finish();
rollback;
