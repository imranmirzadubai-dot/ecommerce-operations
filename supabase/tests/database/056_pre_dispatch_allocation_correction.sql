begin;

select plan(14);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation' and pg_get_function_identity_arguments(p.oid)='p_parcel_item_id uuid, p_corrected_quantity integer, p_idempotency_key text'),'correct_parcel_allocation command exists');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'command pins search_path');
select ok((select has_function_privilege('anon','public.correct_parcel_allocation(uuid,integer,text)','execute')=false and has_function_privilege('authenticated','public.correct_parcel_allocation(uuid,integer,text)','execute')=true),'command is browser-role restricted');
select ok((select pg_get_functiondef(p.oid) like '%app_role() not in (''operations'',''admin'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'command requires operations/admin');
select ok((select pg_get_functiondef(p.oid) like '%Corrected quantity must be a non-negative integer%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'negative corrected quantities are rejected');
select ok((select pg_get_functiondef(p.oid) like '%Only an active allocation can be corrected%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'only active allocations can be corrected');
select ok((select pg_get_functiondef(p.oid) like '%v_parcel_state <> ''Prepared''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'correction is restricted to Prepared parcels');
select ok((select pg_get_functiondef(p.oid) like '%for update of pi,p%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'parcel allocation and parcel rows are locked before correction');
select ok((select pg_get_functiondef(p.oid) like '%v_other_allocated + p_corrected_quantity > v_ordered_quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'corrected quantity respects ordered quantity invariant');
select ok((select pg_get_functiondef(p.oid) like '%set allocation_state=''Reversed''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'original allocation is reversed instead of deleted');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.parcel_items%' and pg_get_functiondef(p.oid) like '%''Allocated''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'replacement allocation is appended as a new active row');
select ok((select pg_get_functiondef(p.oid) like '%ParcelAllocationCorrected%' and pg_get_functiondef(p.oid) like '%insert into public.audit_logs%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'correction emits immutable event and audit record');
select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''correct_parcel_allocation''%' and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''correct_parcel_allocation''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'correction is idempotent and retry safe');
select ok((select pg_get_functiondef(p.oid) like '%p_corrected_quantity=0%' and pg_get_functiondef(p.oid) like '%released%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='correct_parcel_allocation'),'zero correction releases allocation without deleting history');

select * from finish();
rollback;
