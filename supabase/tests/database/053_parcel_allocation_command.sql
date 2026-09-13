begin;

select plan(13);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item' and pg_get_function_identity_arguments(p.oid)='p_parcel_id uuid, p_order_item_id uuid, p_quantity integer, p_idempotency_key text'),'allocate_parcel_item command exists');
select ok((select pg_get_functiondef(p.oid) like '%security definer%set search_path=pg_catalog, public%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'command pins search_path');
select ok((select has_function_privilege('anon','public.allocate_parcel_item(uuid,uuid,integer,text)','execute')=false and has_function_privilege('authenticated','public.allocate_parcel_item(uuid,uuid,integer,text)','execute')=true),'command is browser-role restricted');
select ok((select pg_get_functiondef(p.oid) like '%app_role() not in (''operations'',''admin'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'command requires operations/admin');
select ok((select pg_get_functiondef(p.oid) like '%Allocation quantity must be a positive integer%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'non-positive quantities are rejected');
select ok((select pg_get_functiondef(p.oid) like '%Parcel not found%' and pg_get_functiondef(p.oid) like '%Order item not found%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'missing parcel/order item are rejected');
select ok((select pg_get_functiondef(p.oid) like '%different orders%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'cross-order allocation is rejected');
select ok((select pg_get_functiondef(p.oid) like '%current state%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'terminal/cancelled parcels are rejected');
select ok((select pg_get_functiondef(p.oid) like '%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'parcel and order item rows are locked before allocation');
select ok((select pg_get_functiondef(p.oid) like '%v_allocated_quantity + p_quantity > v_ordered_quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'ordered quantity is checked before mutation');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.parcel_items%' and pg_get_functiondef(p.oid) like '%''Allocated''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'allocation row is created as Allocated');
select ok((select pg_get_functiondef(p.oid) like '%ParcelItemAllocated%' and pg_get_functiondef(p.oid) like '%insert into public.audit_logs%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'allocation emits immutable event and audit record');
select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''allocate_parcel_item''%' and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''allocate_parcel_item''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'allocation is idempotent and retry safe');

select * from finish();
rollback;
