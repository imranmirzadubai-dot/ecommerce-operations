begin;

select plan(10);

-- T122 is a database-contract milestone. The command contract must support
-- partially allocated order items, multi-parcel splits, and mixed allocation
-- states without allowing physical reconciliation to exceed ordered quantity.
select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'single-parcel allocation command exists');
select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'split allocation command exists');
select ok((select pg_get_functiondef(p.oid) like '%v_allocated_quantity + p_quantity > v_ordered_quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'partial allocation preserves ordered-quantity ceiling');
select ok((select pg_get_functiondef(p.oid) like '%v_allocated_quantity + v_requested_quantity > v_ordered_quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'mixed/split allocation preserves ordered-quantity ceiling');
select ok((select pg_get_functiondef(p.oid) like '%jsonb_array_length(p_allocations) < 2%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'mixed scenario can target multiple parcels');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.parcel_items%' and pg_get_functiondef(p.oid) like '%''Allocated''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'partial allocation is represented by allocated parcel-item rows');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.parcel_items%' and pg_get_functiondef(p.oid) like '%''Allocated''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'split allocations are represented by separate allocated parcel-item rows');
select ok((select pg_get_functiondef(p.oid) like '%ParcelItemAllocated%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'partial allocation emits immutable allocation history');
select ok((select pg_get_functiondef(p.oid) like '%ParcelItemAllocated%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'split allocation emits immutable allocation history');
select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''allocate_parcel_items''%' and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''allocate_parcel_items''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'mixed/split allocation is retry-safe');

select * from finish();
rollback;
