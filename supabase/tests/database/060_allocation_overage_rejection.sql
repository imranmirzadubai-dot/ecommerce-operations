begin;

select plan(10);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item' and pg_get_function_identity_arguments(p.oid)='p_parcel_id uuid, p_order_item_id uuid, p_quantity integer, p_idempotency_key text'),'single allocation command exists');
select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items' and pg_get_function_identity_arguments(p.oid)='p_order_item_id uuid, p_allocations jsonb, p_idempotency_key text'),'split allocation command exists');
select ok((select pg_get_functiondef(p.oid) like '%v_allocated_quantity + p_quantity > v_ordered_quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'single allocation explicitly rejects overage beyond ordered quantity');
select ok((select pg_get_functiondef(p.oid) like '%v_allocated_quantity + v_requested_quantity > v_ordered_quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'split allocation explicitly rejects overage beyond ordered quantity');
select ok((select pg_get_functiondef(p.oid) like '%Ordered quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'single allocation exposes ordered-quantity overage failure');
select ok((select pg_get_functiondef(p.oid) like '%Ordered quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'split allocation exposes ordered-quantity overage failure');
select ok((select pg_get_functiondef(p.oid) like '%for update%' and pg_get_functiondef(p.oid) like '%v_allocated_quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'single allocation evaluates the ceiling under row lock');
select ok((select pg_get_functiondef(p.oid) like '%for update%' and pg_get_functiondef(p.oid) like '%v_allocated_quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'split allocation evaluates the ceiling under row lock');
select ok((select pg_get_functiondef(p.oid) like '%raise exception%' and pg_get_functiondef(p.oid) like '%v_allocated_quantity + p_quantity > v_ordered_quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_item'),'single allocation fails before mutation when overage is requested');
select ok((select pg_get_functiondef(p.oid) like '%raise exception%' and pg_get_functiondef(p.oid) like '%v_allocated_quantity + v_requested_quantity > v_ordered_quantity%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='allocate_parcel_items'),'split allocation fails before mutation when overage is requested');

select * from finish();
rollback;
