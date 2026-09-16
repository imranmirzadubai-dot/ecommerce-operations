begin;

select plan(12);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper' and pg_get_function_identity_arguments(p.oid)='p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'),'assign_parcel_shipper command exists');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper'),'command pins search_path');
select ok((select has_function_privilege('anon','public.assign_parcel_shipper(uuid,uuid,text)','execute')=false and has_function_privilege('authenticated','public.assign_parcel_shipper(uuid,uuid,text)','execute')=true),'command is browser-role restricted');
select ok((select pg_get_functiondef(p.oid) like '%app_role() not in (''operations'',''admin'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper'),'command requires operations/admin');
select ok((select pg_get_functiondef(p.oid) like '%v_state<>''Prepared''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper'),'assignment is restricted to Prepared parcels');
select ok((select pg_get_functiondef(p.oid) like '%s.active=true%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper'),'only active shippers may be assigned');
select ok((select pg_get_functiondef(p.oid) like '%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper'),'parcel row is locked before assignment');
select ok((select pg_get_functiondef(p.oid) like '%different shipper is already assigned%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper'),'conflicting reassignment is rejected');
select ok((select pg_get_functiondef(p.oid) like '%set shipper_id=p_shipper_id%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper'),'shipper assignment updates the parcel');
select ok((select pg_get_functiondef(p.oid) like '%ShipperAssigned%' and pg_get_functiondef(p.oid) like '%insert into public.audit_logs%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper'),'assignment emits event and audit record');
select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''assign_parcel_shipper''%' and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''assign_parcel_shipper''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper'),'assignment is idempotent and retry safe');
select ok((select pg_get_functiondef(p.oid) like '%A different shipper is already assigned%' and pg_get_functiondef(p.oid) like '%Active shipper not found%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assign_parcel_shipper'),'assignment has explicit validation errors');

select * from finish();
rollback;
