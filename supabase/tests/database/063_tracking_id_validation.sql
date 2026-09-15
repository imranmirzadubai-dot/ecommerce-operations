begin;

select plan(12);

select ok((select count(*)=1 from information_schema.columns where table_schema='public' and table_name='parcels' and column_name='normalized_tracking_id'),'parcels stores normalized tracking ID');
select ok((select count(*)=1 from pg_indexes where schemaname='public' and indexname='idx_parcels_normalized_tracking_id_unique'),'normalized tracking ID has a unique index');
select ok((select indexdef like '%WHERE (normalized_tracking_id IS NOT NULL)%' from pg_indexes where schemaname='public' and indexname='idx_parcels_normalized_tracking_id_unique'),'unique tracking index permits null tracking IDs');
select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='normalize_tracking_id' and pg_get_function_identity_arguments(p.oid)='p_tracking_id text'),'tracking normalization function exists');
select is(public.normalize_tracking_id('  abc-123  '),'ABC-123','tracking normalization trims and normalizes case');
select is(public.normalize_tracking_id('TrK-001'),'TRK-001','tracking normalization is deterministic');
select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='validate_unique_tracking_id' and pg_get_function_identity_arguments(p.oid)='p_tracking_id text, p_parcel_id uuid'),'unique tracking validation function exists');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='validate_unique_tracking_id'),'validation function is security definer with pinned search_path');
select ok((select has_function_privilege('anon','public.validate_unique_tracking_id(text,uuid)','execute')=false and has_function_privilege('authenticated','public.validate_unique_tracking_id(text,uuid)','execute')=true),'validation function is browser-role restricted');
select ok((select pg_get_functiondef(p.oid) like '%app_role() not in (''operations'',''admin'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='validate_unique_tracking_id'),'validation requires operations/admin');
select ok((select pg_get_functiondef(p.oid) like '%Tracking ID is required%' and pg_get_functiondef(p.oid) like '%conflicting_parcel_id%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='validate_unique_tracking_id'),'validation has explicit required-field and conflict semantics');
select ok((select pg_get_functiondef(p.oid) like '%p.normalized_tracking_id = v_normalized%' and pg_get_functiondef(p.oid) like '%p.id <> p_parcel_id%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='validate_unique_tracking_id'),'validation detects global duplicates while allowing the current parcel');

select * from finish();
rollback;
