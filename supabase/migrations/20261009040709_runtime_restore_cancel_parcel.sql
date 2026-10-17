-- E-Commerce Operations MVP v4.0
-- Formalize parcel cancellation as an idempotent transactional command.

create or replace function public.cancel_parcel(
  p_parcel_id uuid,
  p_idempotency_key text
)
returns table(parcel_id uuid,parcel_number text,state text)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_order_id uuid;
  v_order_number text;
  v_state text;
  v_parcel_number text;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() is null then
    raise exception using errcode='42501',message='Authentication required';
  end if;
  if p_idempotency_key is null or btrim(p_idempotency_key)='' then
    raise exception using errcode='22023',message='Idempotency key is required';
  end if;

  v_hash:=md5(jsonb_build_object('parcel_id',p_parcel_id)::text);
  select is_new,status,result
    into v_is_new,v_status,v_result
  from public.claim_command_idempotency('cancel_parcel',btrim(p_idempotency_key),v_hash);

  if not v_is_new then
    return query
      select (v_result->>'parcel_id')::uuid,
             v_result->>'parcel_number',
             v_result->>'state';
    return;
  end if;

  select p.order_id,p.parcel_number,p.state,o.order_number
    into v_order_id,v_parcel_number,v_state,v_order_number
  from public.parcels p
  join public.orders o on o.id=p.order_id
  where p.id=p_parcel_id
  for update of p;

  if not found then
    raise exception using errcode='P0002',message='Parcel not found';
  end if;

  if v_state<>'Prepared' then
    raise exception using errcode='P0001',message='Only Prepared parcels can be cancelled';
  end if;

  -- Preserve allocation lineage: release active allocations rather than deleting rows.
  update public.parcel_items
     set allocation_state='Reversed',updated_at=now()
   where parcel_id=p_parcel_id
     and allocation_state='Allocated';

  update public.parcels
     set state='Cancelled',updated_at=now()
   where id=p_parcel_id;

  insert into public.order_events(
    order_id,parcel_id,event_type,performed_by,metadata
  ) values (
    v_order_id,p_parcel_id,'ParcelCancelled',auth.uid(),
    jsonb_build_object(
      'from','Prepared',
      'to','Cancelled',
      'order_number',v_order_number,
      'allocation_reversal','applied'
    )
  );

  insert into public.audit_logs(
    actor,action,entity_type,entity_id,before_data,after_data
  ) values (
    auth.uid(),'cancel_parcel','parcel',p_parcel_id,
    jsonb_build_object('state','Prepared'),
    jsonb_build_object('state','Cancelled','order_id',v_order_id)
  );

  v_result:=jsonb_build_object(
    'parcel_id',p_parcel_id,
    'parcel_number',v_parcel_number,
    'state','Cancelled'
  );

  perform public.complete_command_idempotency(
    'cancel_parcel',btrim(p_idempotency_key),v_result
  );

  return query select p_parcel_id,v_parcel_number,'Cancelled'::text;
end;
$$;

revoke all on function public.cancel_parcel(uuid,text) from public;
grant execute on function public.cancel_parcel(uuid,text) to authenticated;
