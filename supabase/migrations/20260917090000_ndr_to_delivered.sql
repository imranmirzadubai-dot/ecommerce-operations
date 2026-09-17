-- P10-T151: authoritative NDR -> Delivered lifecycle transition.
-- Extends record_delivery_outcome so a parcel in NDR may be completed as Delivered.
-- Other terminal outcomes remain available only from In Transit.

create or replace function public.record_delivery_outcome(
  p_parcel_id uuid,
  p_outcome text,
  p_note text,
  p_idempotency_key text
)
returns table(
  parcel_id uuid,
  parcel_number text,
  order_id uuid,
  previous_state text,
  state text,
  outcome_id uuid,
  outcome text,
  note text,
  occurred_at timestamptz
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
  v_outcome_id uuid;
  v_occurred_at timestamptz;
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
  if btrim(coalesce(p_outcome,'')) not in ('Delivered','RTO','Lost','Damaged','NDR') then
    raise exception using errcode='22023', message='Delivery outcome must be Delivered, RTO, Lost, Damaged or NDR';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_hash:=md5(jsonb_build_object(
    'parcel_id',p_parcel_id,
    'outcome',btrim(p_outcome),
    'note',nullif(btrim(coalesce(p_note,'')),'')
  )::text);

  select is_new,status,result
    into v_is_new,v_status,v_result
  from public.claim_command_idempotency('record_delivery_outcome',btrim(p_idempotency_key),v_hash);

  if not v_is_new then
    return query
      select
        (v_result->>'parcel_id')::uuid,
        v_result->>'parcel_number',
        (v_result->>'order_id')::uuid,
        v_result->>'previous_state',
        v_result->>'state',
        (v_result->>'outcome_id')::uuid,
        v_result->>'outcome',
        v_result->>'note',
        (v_result->>'occurred_at')::timestamptz;
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

  if v_state='NDR' and btrim(p_outcome)<>'Delivered' then
    raise exception using errcode='P0001', message='NDR parcels may only transition to Delivered through this command';
  end if;

  if v_state not in ('In Transit','NDR') then
    raise exception using errcode='P0001', message='Only In Transit or NDR parcels can receive a delivery outcome';
  end if;

  v_previous_state:=v_state;
  v_occurred_at:=now();

  update public.parcels
  set state=btrim(p_outcome),
      rto_at=case when btrim(p_outcome)='RTO' then v_occurred_at else rto_at end,
      updated_at=v_occurred_at
  where id=p_parcel_id;

  insert into public.delivery_outcomes(parcel_id,outcome,note,occurred_at,performed_by)
  values(p_parcel_id,btrim(p_outcome),nullif(btrim(coalesce(p_note,'')),''),v_occurred_at,auth.uid())
  returning id into v_outcome_id;

  insert into public.order_events(order_id,parcel_id,event_type,performed_by,notes,metadata)
  values(
    v_order_id,p_parcel_id,btrim(p_outcome),auth.uid(),
    nullif(btrim(coalesce(p_note,'')),''),
    jsonb_build_object(
      'parcel_number',v_parcel_number,
      'previous_state',v_previous_state,
      'state',btrim(p_outcome),
      'outcome_id',v_outcome_id,
      'occurred_at',v_occurred_at
    )
  );

  insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
  values(
    auth.uid(),'record_delivery_outcome','parcel',p_parcel_id,
    jsonb_build_object('state',v_previous_state),
    jsonb_build_object('state',btrim(p_outcome),'outcome',btrim(p_outcome),'outcome_id',v_outcome_id)
  );

  v_result:=jsonb_build_object(
    'parcel_id',p_parcel_id,
    'parcel_number',v_parcel_number,
    'order_id',v_order_id,
    'previous_state',v_previous_state,
    'state',btrim(p_outcome),
    'outcome_id',v_outcome_id,
    'outcome',btrim(p_outcome),
    'note',nullif(btrim(coalesce(p_note,'')),''),
    'occurred_at',v_occurred_at
  );

  perform public.complete_command_idempotency('record_delivery_outcome',btrim(p_idempotency_key),v_result);

  return query
    select p_parcel_id,v_parcel_number,v_order_id,v_previous_state,
           btrim(p_outcome),v_outcome_id,btrim(p_outcome),
           nullif(btrim(coalesce(p_note,'')),''),v_occurred_at;
end;
$$;

revoke execute on function public.record_delivery_outcome(uuid,text,text,text) from anon;
revoke execute on function public.record_delivery_outcome(uuid,text,text,text) from public;
grant execute on function public.record_delivery_outcome(uuid,text,text,text) to authenticated;
