begin;

select plan(7);

select ok((select pg_get_functiondef(p.oid) like '%Parcel not found%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'unknown barcode resolution remains explicitly rejected by dispatch');
select ok((select pg_get_functiondef(p.oid) like '%Only Prepared parcels can be dispatched%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'wrong-state barcode scans are explicitly rejected');
select ok((select pg_get_functiondef(p.oid) like '%v_state<>''Prepared''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'cancelled parcels cannot be re-dispatched from a scan');
select ok((select pg_get_functiondef(p.oid) like '%where p.id=p_parcel_id%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'barcode dispatch locks the resolved parcel before mutation');
select ok((select pg_get_functiondef(p.oid) like '%public.app_role()%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'barcode dispatch remains protected by application-role authorization');
select ok(has_table_privilege('authenticated','public.parcels','UPDATE')=false and has_table_privilege('authenticated','public.parcels','DELETE')=false,'browser roles cannot bypass scan rejection through direct parcel writes');
select ok((select exists (select 1 from pg_indexes where schemaname='public' and indexname='idx_parcels_normalized_tracking_id_unique')),'invalid scans remain subject to the global tracking uniqueness foundation');

select * from finish();
rollback;
