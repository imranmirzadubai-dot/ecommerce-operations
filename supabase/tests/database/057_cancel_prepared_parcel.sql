begin;

select plan(14);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel' and pg_get_function_identity_arguments(p.oid)='p_parcel_id uuid, p_idempotency_key text'),'cancel_parcel command exists');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'command pins search_path');
select ok((select has_function_privilege('anon','public.cancel_parcel(uuid,text)','execute')=false and has_function_privilege('authenticated','public.cancel_parcel(uuid,text)','execute')=true),'command is browser-role restricted');
select ok((select regexp_like(lower(pg_get_functiondef(p.oid)),'auth[[:space:]]*\.[[:space:]]*uid[[:space:]]*\([[:space:]]*\)[[:space:]]+is[[:space:]]+null') and regexp_like(lower(pg_get_functiondef(p.oid)),'public[[:space:]]*\.[[:space:]]*app_role[[:space:]]*\([[:space:]]*\)[[:space:]]+is[[:space:]]+null') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'command requires an authenticated application role');
select ok((select pg_get_functiondef(p.oid) like '%Only Prepared parcels can be cancelled%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'only Prepared parcels can be cancelled');
select ok((select pg_get_functiondef(p.oid) like '%for update of p%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'parcel row is locked before cancellation');
select ok((select pg_get_functiondef(p.oid) like '%allocation_state=''Allocated''%' and pg_get_functiondef(p.oid) like '%allocation_state=''Reversed''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'active allocations are reversed rather than deleted');
select ok((select pg_get_functiondef(p.oid) like '%update public.parcels%' and pg_get_functiondef(p.oid) like '%state=''Cancelled''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'parcel state transitions to Cancelled');
select ok((select pg_get_functiondef(p.oid) like '%ParcelCancelled%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancellation emits a permanent domain event');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.audit_logs%' and pg_get_functiondef(p.oid) like '%''cancel_parcel''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancellation emits audit history');
select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''cancel_parcel''%' and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''cancel_parcel''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancellation is idempotent and retry safe');
select ok((select pg_get_functiondef(p.oid) like '%p_idempotency_key is null or btrim(p_idempotency_key)=''''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'idempotency key is required');
select ok((select pg_get_functiondef(p.oid) like '%where parcel_id=p_parcel_id%' and pg_get_functiondef(p.oid) like '%and allocation_state=''Allocated''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'only active allocations belonging to the parcel are reversed');
select ok((select pg_get_functiondef(p.oid) like '%allocation_reversal%' and pg_get_functiondef(p.oid) like '%ParcelCancelled%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'event records the allocation reversal outcome');

select * from finish();
rollback;
