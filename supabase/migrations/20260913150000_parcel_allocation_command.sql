-- P7-T116: transactional parcel-item allocation.
-- Allocates an ordered item quantity to an existing Prepared/dispatchable parcel,
-- enforcing the authoritative ordered-quantity invariant before mutation.

create or replace function public.allocate_parcel_item(
  p_parcel_id uuid,
  p_order_item_id uuid,
  p_quantity integer,
  p_idempotency_key text
)
returns table(
  parcel_item_id uuid,
  parcel_id uuid,
  order_item_id uuid,
  quantity integer,
  allocation_state text
)
language plpgsql
security definer
set search_path=pg_catalog, public
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
  if auth.uid() is null or public.app_role() not in ('operations','admin') then
    raise exception using errcode='42501', message='Operations or admin role required';
  end if;
  if p_parcel_id is null or p_order_item_id is null then
    raise exception using errcode='22023', message='Parcel and order item are required';
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception using errcode='22023', message='Allocation quantity must be a positive integer';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_hash:=md5(jsonb_build_object('parcel_id',p_parcel_id,'order_item_id',p_order_item_id,'quantity',p_quantity)::text);
  select is_new,status,result into v_is_new,v_status,v_result
  from public.claim_command_idempotency('allocate_parcel_item',btrim(p_idempotency_key),v_hash);

  if not v_is_new then
    return query select
      (v_result->>'parcel_item_id')::uuid,
      (v_result->>'parcel_id')::uuid,
      (v_result->>'order_item_id')::uuid,
      (v_result->>'quantity')::integer,
      v_result->>'allocation_state';
    return;
  end if;

  select p.order_id,p.state into v_parcel_order_id,v_parcel_state
  from public.parcels p where p.id=p_parcel_id for update;
  if not found then raise exception using errcode='P0002', message='Parcel not found'; end if;
  if v_parcel_state in ('Delivered','RTO','Lost','Damaged','Cancelled') then
    raise exception using errcode='P0001', message='Parcel cannot receive a new allocation in its current state';
  end if;

  select oi.order_id,oi.quantity into v_order_item_order_id,v_ordered_quantity
  from public.order_items oi where oi.id=p_order_item_id for update;
  if not found then raise exception using errcode='P0002', message='Order item not found'; end if;
  if v_parcel_order_id <> v_order_item_order_id then
    raise exception using errcode='23514', message='Parcel and order item belong to different orders';
  end if;

  select coalesce(sum(pi.quantity),0)::integer into v_allocated_quantity
  from public.parcel_items pi
  where pi.order_item_id=p_order_item_id and pi.allocation_state='Allocated';
  if v_allocated_quantity + p_quantity > v_ordered_quantity then
    raise exception using errcode='23514', message=format('Parcel allocation exceeds ordered quantity: requested=%s allocated=%s ordered=%s',p_quantity,v_allocated_quantity,v_ordered_quantity);
  end if;

  insert into public.parcel_items(parcel_id,order_item_id,quantity,allocation_state)
  values(p_parcel_id,p_order_item_id,p_quantity,'Allocated')
  returning id into v_parcel_item_id;

  insert into public.order_events(order_id,parcel_id,event_type,performed_by,metadata)
  values(v_parcel_order_id,p_parcel_id,'ParcelItemAllocated',auth.uid(),jsonb_build_object('order_item_id',p_order_item_id,'quantity',p_quantity,'parcel_item_id',v_parcel_item_id));

  insert into public.audit_logs(actor,action,entity_type,entity_id,after_data)
  values(auth.uid(),'allocate_parcel_item','parcel_item',v_parcel_item_id,jsonb_build_object('parcel_id',p_parcel_id,'order_item_id',p_order_item_id,'quantity',p_quantity,'allocation_state','Allocated'));

  v_result:=jsonb_build_object('parcel_item_id',v_parcel_item_id,'parcel_id',p_parcel_id,'order_item_id',p_order_item_id,'quantity',p_quantity,'allocation_state','Allocated');
  perform public.complete_command_idempotency('allocate_parcel_item',btrim(p_idempotency_key),v_result);
  return query select v_parcel_item_id,p_parcel_id,p_order_item_id,p_quantity,'Allocated'::text;
end;
$$;

revoke execute on function public.allocate_parcel_item(uuid,uuid,integer,text) from anon;
revoke execute on function public.allocate_parcel_item(uuid,uuid,integer,text) from public;
grant execute on function public.allocate_parcel_item(uuid,uuid,integer,text) to authenticated;
