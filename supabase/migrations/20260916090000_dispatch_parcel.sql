-- P9-T140: transactional parcel dispatch.
-- Dispatch resolves and locks the parcel, validates the Prepared state,
-- assigned active shipper and unique tracking ID, then records the transition.

create or replace function public.dispatch_parcel(
  p_parcel_id uuid,
  p_tracking_id text,
  p_idempotency_key text
)
returns table(
  parcel_id uuid,
  parcel_number text,
  order_id uuid,
  shipper_id uuid,
  shipper_name text,
  tracking_id text,
  normalized_tracking_id text,
  state text,
  dispatch_at timestamptz
)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_parcel_number text;
  v_order_id uuid;
  v_state text;
  v_shipper_id uuid;
  v_shipper_name text;
  v_normalized_tracking_id text;
  v_dispatch_at timestamptz;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('operations','admin') then
    raise exception using errcode='42501', message='Operations or admin role required';
  end if;
  if p_parcel_id is null then
    raise exception using errcode='22023', message='Parcel ID is required';
  end if;
  if btrim(coalesce(p_tracking_id,''))='' then
    raise exception using errcode='22023', message='Tracking ID is required';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_hash:=md5(jsonb_build_object('parcel_id',p_parcel_id,'tracking_id',btrim(p_tracking_id))::text);
  select is_new,status,result
    into v_is_new,v_status,v_result
  from public.claim_command_idempotency('dispatch_parcel',btrim(p_idempotency_key),v_hash);

  if not v_is_new then
    return query
      select
        (v_result->>'parcel_id')::uuid,
        v_result->>'parcel_number',
        (v_result->>'order_id')::uuid,
        (v_result->>'shipper_id')::uuid,
        v_result->>'shipper_name',
        v_result->>'tracking_id',
        v_result->>'normalized_tracking_id',
        v_result->>'state',
        (v_result->>'dispatch_at')::timestamptz;
    return;
  end if;

  select p.parcel_number,p.order_id,p.state,p.shipper_id
    into v_parcel_number,v_order_id,v_state,v_shipper_id
  from public.parcels p
  where p.id=p_parcel_id
  for update;

  if not found then
    raise exception using errcode='P0002', message='Parcel not found';
  end if;

  if v_state<>'Prepared' then
    raise exception using errcode='P0001', message='Only Prepared parcels can be dispatched';
  end if;

  if v_shipper_id is null then
    raise exception using errcode='P0001', message='Active shipper is required before dispatch';
  end if;

  select s.name
    into v_shipper_name
  from public.shippers s
  where s.id=v_shipper_id
    and s.active=true;

  if not found then
    raise exception using errcode='P0001', message='Assigned shipper is not active';
  end if;

  select v.normalized_tracking_id
    into v_normalized_tracking_id
  from public.validate_unique_tracking_id(btrim(p_tracking_id),p_parcel_id) v;

  v_dispatch_at:=now();

  update public.parcels
  set tracking_id=btrim(p_tracking_id),
      normalized_tracking_id=v_normalized_tracking_id,
      state='Dispatched',
      dispatch_at=v_dispatch_at,
      updated_at=v_dispatch_at
  where id=p_parcel_id;

  insert into public.order_events(
    order_id,parcel_id,event_type,performed_by,metadata
  )
  values(
    v_order_id,p_parcel_id,'Dispatched',auth.uid(),
    jsonb_build_object(
      'parcel_number',v_parcel_number,
      'shipper_id',v_shipper_id,
      'shipper_name',v_shipper_name,
      'tracking_id',btrim(p_tracking_id),
      'normalized_tracking_id',v_normalized_tracking_id,
      'state','Dispatched',
      'dispatch_at',v_dispatch_at
    )
  );

  insert into public.audit_logs(
    actor,action,entity_type,entity_id,before_data,after_data
  )
  values(
    auth.uid(),'dispatch_parcel','parcel',p_parcel_id,
    jsonb_build_object('state','Prepared','shipper_id',v_shipper_id),
    jsonb_build_object(
      'state','Dispatched',
      'shipper_id',v_shipper_id,
      'shipper_name',v_shipper_name,
      'tracking_id',btrim(p_tracking_id),
      'normalized_tracking_id',v_normalized_tracking_id,
      'dispatch_at',v_dispatch_at
    )
  );

  v_result:=jsonb_build_object(
    'parcel_id',p_parcel_id,
    'parcel_number',v_parcel_number,
    'order_id',v_order_id,
    'shipper_id',v_shipper_id,
    'shipper_name',v_shipper_name,
    'tracking_id',btrim(p_tracking_id),
    'normalized_tracking_id',v_normalized_tracking_id,
    'state','Dispatched',
    'dispatch_at',v_dispatch_at
  );
  perform public.complete_command_idempotency('dispatch_parcel',btrim(p_idempotency_key),v_result);

  return query
    select p_parcel_id,v_parcel_number,v_order_id,v_shipper_id,v_shipper_name,
           btrim(p_tracking_id),v_normalized_tracking_id,'Dispatched'::text,v_dispatch_at;
end;
$$;

revoke execute on function public.dispatch_parcel(uuid,text,text) from anon;
revoke execute on function public.dispatch_parcel(uuid,text,text) from public;
grant execute on function public.dispatch_parcel(uuid,text,text) to authenticated;
