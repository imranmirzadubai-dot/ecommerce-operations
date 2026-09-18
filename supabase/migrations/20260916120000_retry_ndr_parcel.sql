-- P10-T150: authoritative NDR retry transition.
-- NDR is non-terminal; this command moves NDR back to In Transit for another delivery attempt.

create or replace function public.retry_ndr_parcel(
  p_parcel_id uuid,
  p_note text,
  p_idempotency_key text
)
returns table(
  parcel_id uuid,
  parcel_number text,
  order_id uuid,
  previous_state text,
  state text,
  note text,
  retried_at timestamptz
)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_parcel_number text;
  v_order_id uuid;
  v_state text;
  v_previous_state text;
  v_retried_at timestamptz;
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
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_hash:=md5(jsonb_build_object(
    'parcel_id',p_parcel_id,
    'note',nullif(btrim(coalesce(p_note,'')),'')
  )::text);

  select is_new,status,result
    into v_is_new,v_status,v_result
  from public.claim_command_idempotency('retry_ndr_parcel',btrim(p_idempotency_key),v_hash);

  if not v_is_new then
    return query
      select
        (v_result->>'parcel_id')::uuid,
        v_result->>'parcel_number',
        (v_result->>'order_id')::uuid,
        v_result->>'previous_state',
        v_result->>'state',
        v_result->>'note',
        (v_result->>'retried_at')::timestamptz;
    return;
  end if;

  select p.parcel_number,p.order_id,p.state
    into v_parcel_number,v_order_id,v_state
  from public.parcels p
  where p.id=p_parcel_id
  for update;

  if not found then
    raise exception using errcode='P0002', message='Parcel not found';
  end if;

  if v_state<>'NDR' then
    raise exception using errcode='P0001', message='Only NDR parcels can be retried';
  end if;

  v_previous_state:=v_state;
  v_retried_at:=now();

  update public.parcels
  set state='In Transit',
      updated_at=v_retried_at
  where id=p_parcel_id;

  insert into public.order_events(order_id,parcel_id,event_type,performed_by,notes,metadata)
  values(
    v_order_id,p_parcel_id,'NDR Retry',auth.uid(),
    nullif(btrim(coalesce(p_note,'')),''),
    jsonb_build_object(
      'parcel_number',v_parcel_number,
      'previous_state',v_previous_state,
      'state','In Transit',
      'retried_at',v_retried_at
    )
  );

  insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
  values(
    auth.uid(),'retry_ndr_parcel','parcel',p_parcel_id,
    jsonb_build_object('state',v_previous_state),
    jsonb_build_object('state','In Transit','reason','NDR retry','retried_at',v_retried_at)
  );

  v_result:=jsonb_build_object(
    'parcel_id',p_parcel_id,
    'parcel_number',v_parcel_number,
    'order_id',v_order_id,
    'previous_state',v_previous_state,
    'state','In Transit',
    'note',nullif(btrim(coalesce(p_note,'')),''),
    'retried_at',v_retried_at
  );

  perform public.complete_command_idempotency('retry_ndr_parcel',btrim(p_idempotency_key),v_result);

  return query
    select p_parcel_id,v_parcel_number,v_order_id,v_previous_state,
           'In Transit',nullif(btrim(coalesce(p_note,'')),''),v_retried_at;
end;
$$;

revoke execute on function public.retry_ndr_parcel(uuid,text,text) from anon;
revoke execute on function public.retry_ndr_parcel(uuid,text,text) from public;
grant execute on function public.retry_ndr_parcel(uuid,text,text) to authenticated;
