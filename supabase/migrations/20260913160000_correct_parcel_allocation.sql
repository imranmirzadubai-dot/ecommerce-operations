-- P7-T119: pre-dispatch allocation correction.
-- Corrections never rewrite or delete the original allocation row. The original
-- allocation is marked Reversed and, when needed, a new Allocated row records
-- the corrected quantity. Only Prepared parcels are eligible.

create or replace function public.correct_parcel_allocation(
  p_parcel_item_id uuid,
  p_corrected_quantity integer,
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
  v_parcel_id uuid;
  v_order_item_id uuid;
  v_order_id uuid;
  v_parcel_state text;
  v_old_quantity integer;
  v_ordered_quantity integer;
  v_other_allocated integer;
  v_new_id uuid;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('operations','admin') then
    raise exception using errcode='42501', message='Operations or admin role required';
  end if;
  if p_parcel_item_id is null then
    raise exception using errcode='22023', message='Parcel item is required';
  end if;
  if p_corrected_quantity is null or p_corrected_quantity < 0 then
    raise exception using errcode='22023', message='Corrected quantity must be a non-negative integer';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_hash:=md5(jsonb_build_object('parcel_item_id',p_parcel_item_id,'corrected_quantity',p_corrected_quantity)::text);
  select is_new,status,result into v_is_new,v_status,v_result
  from public.claim_command_idempotency('correct_parcel_allocation',btrim(p_idempotency_key),v_hash);

  if not v_is_new then
    if coalesce(v_result->>'released','false')='true' then
      return;
    end if;
    return query select
      (v_result->>'parcel_item_id')::uuid,
      (v_result->>'parcel_id')::uuid,
      (v_result->>'order_item_id')::uuid,
      (v_result->>'quantity')::integer,
      v_result->>'allocation_state';
    return;
  end if;

  select pi.parcel_id,pi.order_item_id,pi.quantity,pi.allocation_state,p.order_id,p.state
    into v_parcel_id,v_order_item_id,v_old_quantity,v_status,v_order_id,v_parcel_state
  from public.parcel_items pi
  join public.parcels p on p.id=pi.parcel_id
  where pi.id=p_parcel_item_id
  for update of pi,p;

  if not found then
    raise exception using errcode='P0002', message='Parcel item not found';
  end if;
  if v_status <> 'Allocated' then
    raise exception using errcode='P0001', message='Only an active allocation can be corrected';
  end if;
  if v_parcel_state <> 'Prepared' then
    raise exception using errcode='P0001', message='Allocation correction is permitted only while parcel is Prepared';
  end if;

  select oi.quantity into v_ordered_quantity
  from public.order_items oi
  where oi.id=v_order_item_id
  for update;
  if not found then
    raise exception using errcode='P0002', message='Order item not found';
  end if;

  select coalesce(sum(pi.quantity),0)::integer into v_other_allocated
  from public.parcel_items pi
  where pi.order_item_id=v_order_item_id
    and pi.allocation_state='Allocated'
    and pi.id<>p_parcel_item_id;

  if v_other_allocated + p_corrected_quantity > v_ordered_quantity then
    raise exception using errcode='23514', message=format('Corrected allocation exceeds ordered quantity: corrected=%s other_allocated=%s ordered=%s',p_corrected_quantity,v_other_allocated,v_ordered_quantity);
  end if;

  update public.parcel_items
  set allocation_state='Reversed'
  where id=p_parcel_item_id;

  if p_corrected_quantity=0 then
    v_result:=jsonb_build_object('released',true,'parcel_item_id',p_parcel_item_id,'parcel_id',v_parcel_id,'order_item_id',v_order_item_id,'quantity',0,'allocation_state','Reversed');
    insert into public.order_events(order_id,parcel_id,event_type,performed_by,metadata)
    values(v_order_id,v_parcel_id,'ParcelAllocationCorrected',auth.uid(),jsonb_build_object('original_parcel_item_id',p_parcel_item_id,'old_quantity',v_old_quantity,'corrected_quantity',0,'allocation_state','Reversed'));
    insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
    values(auth.uid(),'correct_parcel_allocation','parcel_item',p_parcel_item_id,jsonb_build_object('quantity',v_old_quantity,'allocation_state','Allocated'),jsonb_build_object('quantity',0,'allocation_state','Reversed'));
    perform public.complete_command_idempotency('correct_parcel_allocation',btrim(p_idempotency_key),v_result);
    return;
  end if;

  insert into public.parcel_items(parcel_id,order_item_id,quantity,allocation_state)
  values(v_parcel_id,v_order_item_id,p_corrected_quantity,'Allocated')
  returning id into v_new_id;

  insert into public.order_events(order_id,parcel_id,event_type,performed_by,metadata)
  values(v_order_id,v_parcel_id,'ParcelAllocationCorrected',auth.uid(),jsonb_build_object('original_parcel_item_id',p_parcel_item_id,'replacement_parcel_item_id',v_new_id,'old_quantity',v_old_quantity,'corrected_quantity',p_corrected_quantity,'allocation_state','Allocated'));
  insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
  values(auth.uid(),'correct_parcel_allocation','parcel_item',p_parcel_item_id,jsonb_build_object('quantity',v_old_quantity,'allocation_state','Allocated'),jsonb_build_object('replacement_parcel_item_id',v_new_id,'quantity',p_corrected_quantity,'allocation_state','Allocated'));

  v_result:=jsonb_build_object('parcel_item_id',v_new_id,'parcel_id',v_parcel_id,'order_item_id',v_order_item_id,'quantity',p_corrected_quantity,'allocation_state','Allocated');
  perform public.complete_command_idempotency('correct_parcel_allocation',btrim(p_idempotency_key),v_result);
  return query select v_new_id,v_parcel_id,v_order_item_id,p_corrected_quantity,'Allocated'::text;
end;
$$;

revoke execute on function public.correct_parcel_allocation(uuid,integer,text) from anon;
revoke execute on function public.correct_parcel_allocation(uuid,integer,text) from public;
grant execute on function public.correct_parcel_allocation(uuid,integer,text) to authenticated;
