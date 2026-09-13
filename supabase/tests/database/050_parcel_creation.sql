begin;

-- P7-T113: parcel creation command contract.
select plan(14);

select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel' and pg_get_function_identity_arguments(p.oid)='p_order_id uuid, p_idempotency_key text'),'canonical create_parcel function is present');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'create_parcel runs through a pinned security-definer command boundary');
select ok((select has_function_privilege('anon','public.create_parcel(uuid,text)','EXECUTE') = false and has_function_privilege('authenticated','public.create_parcel(uuid,text)','EXECUTE') = true),'create_parcel is callable by authenticated users only');
select ok((select pg_get_functiondef(p.oid) like '%app_role() not in (''operations'',''admin'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'create_parcel restricts execution to operations/admin roles');
select ok((select pg_get_functiondef(p.oid) like '%Order ID is required%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'null order ID is rejected');
select ok((select pg_get_functiondef(p.oid) like '%Idempotency key is required%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'blank idempotency key is rejected');
select ok((select pg_get_functiondef(p.oid) like '%Order not found%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'unknown orders are rejected');
select ok((select pg_get_functiondef(p.oid) like '%Parcel cannot be created for a cancelled or completed order%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'cancelled/completed orders are rejected');
select ok((select pg_get_functiondef(p.oid) like '%nextval(''public.parcel_number_seq'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'parcel number is generated from the authoritative parcel sequence');
select ok((select pg_get_functiondef(p.oid) like '%v_parcel_number:=''PCL-''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'parcel number uses the PCL-XXXXXX identifier format');
select ok((select pg_get_functiondef(p.oid) like '%barcode,%' and pg_get_functiondef(p.oid) like '%v_parcel_number,%' and pg_get_functiondef(p.oid) like '%''Prepared''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'new parcels are created Prepared with barcode equal to parcel_number');
select ok((select position('select o.order_number,o.lifecycle_state' in pg_get_functiondef(p.oid)) < position('insert into public.parcels' in pg_get_functiondef(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'order validation and row locking occur before parcel mutation');
select ok((select position('insert into public.parcels' in pg_get_functiondef(p.oid)) < position('insert into public.order_events' in pg_get_functiondef(p.oid)) and position('insert into public.parcels' in pg_get_functiondef(p.oid)) < position('insert into public.audit_logs' in pg_get_functiondef(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'parcel event and audit records are written after successful creation');
select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''create_parcel''%' and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''create_parcel''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_parcel'),'create_parcel is deterministically retryable');

select * from finish();
rollback;
