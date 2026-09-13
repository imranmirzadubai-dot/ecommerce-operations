-- P7-T124: normal allocation is permitted only while a parcel is Prepared.
-- After Dispatch, allocation is immutable. Exceptional corrections use a
-- separately authorized operational correction path and never mutate this
-- normal allocation command contract.

create or replace function public.allocate_parcel_item(
  p_parcel_id uuid,
  p_order_item_id uuid,
  p_quantity integer,
  p_idempotency_key text
)
returns table(parcel_item_id uuid, parcel_id uuid, order_item_id uuid, quantity integer, allocation_state text)
language plpgsql security definer set search_path=pg_catalog, public
as $$
declare
  v_parcel_order_id uuid;
  v_order_item_order_id uuid;
  v_parcel_state text;
  v_ordered_quantity integer;
  v_allocated_quantity integer;
  v_parcel_item_id uuid;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('operations','admin') then raise exception using errcode='42501', message='Operations or admin role required'; end if;
  if p_parcel_id is null or p_order_item_id is null then raise exception using errcode='22023', message='Parcel and order item are required'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception using errcode='22023', message='Allocation quantity must be a positive integer'; end if;
  if btrim(coalesce(p_idempotency_key,''))='' then raise exception using errcode='22023', message='Idempotency key is required'; end if;

  v_hash:=md5(jsonb_build_object('parcel_id',p_parcel_id,'order_item_id',p_order_item_id,'quantity',p_quantity)::text);
  select is_new,status,result into v_is_new,v_status,v_result from public.claim_command_idempotency('allocate_parcel_item',btrim(p_idempotency_key),v_hash);
  if not v_is_new then
    return query select (v_result->>'parcel_item_id')::uuid,(v_result->>'parcel_id')::uuid,(v_result->>'order_item_id')::uuid,(v_result->>'quantity')::integer,v_result->>'allocation_state';
    return;
  end if;

  select p.order_id,p.state into v_parcel_order_id,v_parcel_state from public.parcels p where p.id=p_parcel_id for update;
  if not found then raise exception using errcode='P0002', message='Parcel not found'; end if;
  if v_parcel_state <> 'Prepared' then raise exception using errcode='P0001', message='Parcel allocation is permitted only while parcel is Prepared'; end if;

  select oi.order_id,oi.quantity into v_order_item_order_id,v_ordered_quantity from public.order_items oi where oi.id=p_order_item_id for update;
  if not found then raise exception using errcode='P0002', message='Order item not found'; end if;
  if v_parcel_order_id <> v_order_item_order_id then raise exception using errcode='23514', message='Parcel and order item belong to different orders'; end if;

  select coalesce(sum(pi.quantity),0)::integer into v_allocated_quantity from public.parcel_items pi where pi.order_item_id=p_order_item_id and pi.allocation_state='Allocated';
  if v_allocated_quantity + p_quantity > v_ordered_quantity then
    raise exception using errcode='23514', message=format('Parcel allocation exceeds ordered quantity: requested=%s allocated=%s ordered=%s',p_quantity,v_allocated_quantity,v_ordered_quantity);
  end if;

  insert into public.parcel_items(parcel_id,order_item_id,quantity,allocation_state) values(p_parcel_id,p_order_item_id,p_quantity,'Allocated') returning id into v_parcel_item_id;
  insert into public.order_events(order_id,parcel_id,event_type,performed_by,metadata) values(v_parcel_order_id,p_parcel_id,'ParcelItemAllocated',auth.uid(),jsonb_build_object('order_item_id',p_order_item_id,'quantity',p_quantity,'parcel_item_id',v_parcel_item_id));
  insert into public.audit_logs(actor,action,entity_type,entity_id,after_data) values(auth.uid(),'allocate_parcel_item','parcel_item',v_parcel_item_id,jsonb_build_object('parcel_id',p_parcel_id,'order_item_id',p_order_item_id,'quantity',p_quantity,'allocation_state','Allocated'));
  v_result:=jsonb_build_object('parcel_item_id',v_parcel_item_id,'parcel_id',p_parcel_id,'order_item_id',p_order_item_id,'quantity',p_quantity,'allocation_state','Allocated');
  perform public.complete_command_idempotency('allocate_parcel_item',btrim(p_idempotency_key),v_result);
  return query select v_parcel_item_id,p_parcel_id,p_order_item_id,p_quantity,'Allocated'::text;
end;
$$;

create or replace function public.allocate_parcel_items(
  p_order_item_id uuid,
  p_allocations jsonb,
  p_idempotency_key text
)
returns table(parcel_item_id uuid, parcel_id uuid, order_item_id uuid, quantity integer, allocation_state text)
language plpgsql security definer set search_path=pg_catalog, public
as $$
declare
  v_order_id uuid;
  v_ordered_quantity integer;
  v_allocated_quantity integer;
  v_requested_quantity integer;
  v_parcel_count integer;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
  v_row record;
  v_parcel_item_id uuid;
begin
  if auth.uid() is null or public.app_role() not in ('operations','admin') then raise exception using errcode='42501', message='Operations or admin role required'; end if;
  if p_order_item_id is null then raise exception using errcode='22023', message='Order item is required'; end if;
  if jsonb_typeof(p_allocations) <> 'array' then raise exception using errcode='22023', message='Allocations must be a JSON array'; end if;
  if jsonb_array_length(p_allocations) < 2 then raise exception using errcode='22023', message='Split allocation requires at least two parcels'; end if;
  if btrim(coalesce(p_idempotency_key,''))='' then raise exception using errcode='22023', message='Idempotency key is required'; end if;

  v_hash:=md5(jsonb_build_object('order_item_id',p_order_item_id,'allocations',p_allocations)::text);
  select is_new,status,result into v_is_new,v_status,v_result from public.claim_command_idempotency('allocate_parcel_items',btrim(p_idempotency_key),v_hash);
  if not v_is_new then
    return query select r.parcel_item_id,r.parcel_id,r.order_item_id,r.quantity,r.allocation_state from jsonb_to_recordset(v_result) as r(parcel_item_id uuid,parcel_id uuid,order_item_id uuid,quantity integer,allocation_state text);
    return;
  end if;

  select oi.order_id,oi.quantity into v_order_id,v_ordered_quantity from public.order_items oi where oi.id=p_order_item_id for update;
  if not found then raise exception using errcode='P0002', message='Order item not found'; end if;

  select count(distinct x.parcel_id),coalesce(sum(x.quantity),0)::integer into v_parcel_count,v_requested_quantity from jsonb_to_recordset(p_allocations) as x(parcel_id uuid,quantity integer);
  if exists (select 1 from jsonb_to_recordset(p_allocations) as x(parcel_id uuid,quantity integer) where x.parcel_id is null or x.quantity is null or x.quantity <= 0) then raise exception using errcode='22023', message='Allocation quantities must be positive integers and parcel IDs are required'; end if;
  if v_parcel_count <> jsonb_array_length(p_allocations) then raise exception using errcode='23505', message='Each parcel may appear only once in a split allocation'; end if;
  if v_requested_quantity <= 0 then raise exception using errcode='22023', message='Allocation quantities must be positive integers'; end if;
  if v_requested_quantity > v_ordered_quantity then raise exception using errcode='23514', message=format('Split allocation exceeds ordered quantity: requested=%s ordered=%s',v_requested_quantity,v_ordered_quantity); end if;

  for v_row in select x.parcel_id,x.quantity from jsonb_to_recordset(p_allocations) as x(parcel_id uuid,quantity integer) order by x.parcel_id loop
    perform 1 from public.parcels p where p.id=v_row.parcel_id and p.order_id=v_order_id for update;
    if not found then raise exception using errcode='23514', message='Parcel does not belong to the order item order'; end if;
    if (select p.state from public.parcels p where p.id=v_row.parcel_id) <> 'Prepared' then raise exception using errcode='P0001', message='Split allocation is permitted only while parcel is Prepared'; end if;
  end loop;

  select coalesce(sum(pi.quantity),0)::integer into v_allocated_quantity from public.parcel_items pi where pi.order_item_id=p_order_item_id and pi.allocation_state='Allocated';
  if v_allocated_quantity + v_requested_quantity > v_ordered_quantity then raise exception using errcode='23514', message=format('Split allocation exceeds remaining quantity: requested=%s allocated=%s ordered=%s',v_requested_quantity,v_allocated_quantity,v_ordered_quantity); end if;

  v_result:='[]'::jsonb;
  for v_row in select x.parcel_id,x.quantity from jsonb_to_recordset(p_allocations) as x(parcel_id uuid,quantity integer) order by x.parcel_id loop
    insert into public.parcel_items(parcel_id,order_item_id,quantity,allocation_state) values(v_row.parcel_id,p_order_item_id,v_row.quantity,'Allocated') returning id into v_parcel_item_id;
    insert into public.order_events(order_id,parcel_id,event_type,performed_by,metadata) values(v_order_id,v_row.parcel_id,'ParcelItemAllocated',auth.uid(),jsonb_build_object('order_item_id',p_order_item_id,'quantity',v_row.quantity,'parcel_item_id',v_parcel_item_id,'split_allocation',true));
    insert into public.audit_logs(actor,action,entity_type,entity_id,after_data) values(auth.uid(),'allocate_parcel_items','parcel_item',v_parcel_item_id,jsonb_build_object('parcel_id',v_row.parcel_id,'order_item_id',p_order_item_id,'quantity',v_row.quantity,'allocation_state','Allocated','split_allocation',true));
    v_result:=v_result || jsonb_build_array(jsonb_build_object('parcel_item_id',v_parcel_item_id,'parcel_id',v_row.parcel_id,'order_item_id',p_order_item_id,'quantity',v_row.quantity,'allocation_state','Allocated'));
  end loop;
  perform public.complete_command_idempotency('allocate_parcel_items',btrim(p_idempotency_key),v_result);
  return query select r.parcel_item_id,r.parcel_id,r.order_item_id,r.quantity,r.allocation_state from jsonb_to_recordset(v_result) as r(parcel_item_id uuid,parcel_id uuid,order_item_id uuid,quantity integer,allocation_state text);
end;
$$;

revoke execute on function public.allocate_parcel_item(uuid,uuid,integer,text) from anon;
revoke execute on function public.allocate_parcel_item(uuid,uuid,integer,text) from public;
grant execute on function public.allocate_parcel_item(uuid,uuid,integer,text) to authenticated;
revoke execute on function public.allocate_parcel_items(uuid,jsonb,text) from anon;
revoke execute on function public.allocate_parcel_items(uuid,jsonb,text) from public;
grant execute on function public.allocate_parcel_items(uuid,jsonb,text) to authenticated;
