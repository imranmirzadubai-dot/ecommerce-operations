begin;

select plan(8);

select ok((select pg_get_functiondef(p.oid) like '%Parcel not found%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'unknown parcel is rejected by the dispatch command');
select ok((select pg_get_functiondef(p.oid) like '%Only Prepared parcels can be dispatched%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'wrong-state parcels are rejected by the dispatch command');
select ok((select pg_get_functiondef(p.oid) like '%state<>''Prepared''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'dispatch command blocks every non-Prepared state including Cancelled');
select ok((select pg_get_functiondef(p.oid) like '%v_state<>''Prepared''%' and pg_get_functiondef(p.oid) like '%Only Prepared parcels can be dispatched%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'wrong-state rejection occurs before mutation');
select ok((select pg_get_functiondef(p.oid) like '%Parcel not found%' and pg_get_functiondef(p.oid) like '%Only Prepared parcels can be dispatched%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'unknown and wrong-state scans have explicit command errors');
select ok((select exists (select 1 from pg_indexes where schemaname='public' and indexname='idx_parcels_normalized_tracking_id_unique')),'invalid dispatch cannot bypass the established tracking uniqueness boundary');
select ok((select has_table_privilege('authenticated','public.parcels','UPDATE')=false and has_table_privilege('authenticated','public.parcels','DELETE')=false),'invalid scans cannot mutate parcel rows directly from the browser role');
select ok((select pg_get_functiondef(p.oid) like '%if auth.uid() is null%' and pg_get_functiondef(p.oid) like '%public.app_role()%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'scan dispatch remains protected by database authorization');

select * from finish();
rollback;
