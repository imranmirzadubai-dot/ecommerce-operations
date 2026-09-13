-- P7-T113: transactional parcel creation.
-- Creates a Prepared parcel for an eligible order, emits an immutable event/audit record,
-- and makes retries deterministic through the shared idempotency contract.

create or replace function public.create_parcel(
  p_order_id uuid,
  p_idempotency_key text
)
returns table(
  parcel_id uuid,
  parcel_number text,
  barcode text,
  order_id uuid,
  state text
)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_order_number text;
  v_lifecycle_state text;
  v_parcel_id uuid;
  v_parcel_number text;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('operations','admin') then
    raise exception using errcode='42501', message='Operations or admin role required';
  end if;
  if p_order_id is null then
    raise exception using errcode='22023', message='Order ID is required';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_hash:=md5(jsonb_build_object('order_id',p_order_id)::text);
  select is_new,status,result
    into v_is_new,v_status,v_result
  from public.claim_command_idempotency('create_parcel',btrim(p_idempotency_key),v_hash);

  if not v_is_new then
    return query
      select
        (v_result->>'parcel_id')::uuid,
        v_result->>'parcel_number',
        v_result->>'barcode',
        (v_result->>'order_id')::uuid,
        v_result->>'state';
    return;
  end if;

  select o.order_number,o.lifecycle_state
    into v_order_number,v_lifecycle_state
  from public.orders o
  where o.id=p_order_id
  for update;

  if not found then
    raise exception using errcode='P0002', message='Order not found';
  end if;

  if v_lifecycle_state not in ('Draft','Confirmed','Active') then
    raise exception using errcode='P0001', message='Parcel cannot be created for a cancelled or completed order';
  end if;

  v_parcel_number:='PCL-' || lpad(nextval('public.parcel_number_seq')::text,6,'0');

  insert into public.parcels(
    order_id,
    parcel_number,
    barcode,
    state
  )
  values(
    p_order_id,
    v_parcel_number,
    v_parcel_number,
    'Prepared'
  )
  returning id into v_parcel_id;

  insert into public.order_events(
    order_id,
    parcel_id,
    event_type,
    performed_by,
    metadata
  )
  values(
    p_order_id,
    v_parcel_id,
    'ParcelCreated',
    auth.uid(),
    jsonb_build_object(
      'order_number',v_order_number,
      'parcel_number',v_parcel_number,
      'state','Prepared'
    )
  );

  insert into public.audit_logs(
    actor,
    action,
    entity_type,
    entity_id,
    after_data
  )
  values(
    auth.uid(),
    'create_parcel',
    'parcel',
    v_parcel_id,
    jsonb_build_object(
      'order_id',p_order_id,
      'order_number',v_order_number,
      'parcel_number',v_parcel_number,
      'barcode',v_parcel_number,
      'state','Prepared'
    )
  );

  v_result:=jsonb_build_object(
    'parcel_id',v_parcel_id,
    'parcel_number',v_parcel_number,
    'barcode',v_parcel_number,
    'order_id',p_order_id,
    'state','Prepared'
  );
  perform public.complete_command_idempotency('create_parcel',btrim(p_idempotency_key),v_result);

  return query
    select v_parcel_id,v_parcel_number,v_parcel_number,p_order_id,'Prepared'::text;
end;
$$;

revoke all on function public.create_parcel(uuid,text) from public;
grant execute on function public.create_parcel(uuid,text) to authenticated;
