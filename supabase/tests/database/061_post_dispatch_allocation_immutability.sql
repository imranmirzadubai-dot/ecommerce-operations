begin;

select plan(9);

-- P7-T124: after dispatch, allocation is immutable. Normal allocation and
-- pre-dispatch correction paths must only operate on Prepared parcels.
select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'single allocation command exists');
select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'split allocation command exists');
select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'pre-dispatch correction command exists');
select ok((select pg_get_functiondef(p.oid) like '%v_parcel_state <> ''Prepared''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'single allocation is restricted to Prepared parcels');
select ok((select pg_get_functiondef(p.oid) like '%v_parcel_state <> ''Prepared''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'split allocation is restricted to Prepared parcels');
select ok((select pg_get_functiondef(p.oid) like '%v_parcel_state <> ''Prepared''%' and pg_get_functiondef(p.oid) like '%Allocation correction is permitted only while parcel is Prepared%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'allocation correction is restricted to Prepared parcels');
select ok((select pg_get_functiondef(p.oid) like '%Parcel allocation is permitted only while parcel is Prepared%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'single allocation exposes post-dispatch rejection contract');
select ok((select pg_get_functiondef(p.oid) like '%Split allocation is permitted only while parcel is Prepared%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'split allocation exposes post-dispatch rejection contract');
select ok((select pg_get_functiondef(p.oid) not like '%if v_parcel_state in (''Delivered'',''RTO'',''Lost'',''Damaged'',''Cancelled'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'single allocation does not allow any post-dispatch parcel state');

select * from finish();
rollback;
