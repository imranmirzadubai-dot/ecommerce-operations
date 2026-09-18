begin;

-- P11-T168: allocate an explicit expected COD amount from an order-level
-- obligation to one of that obligation's parcels.
create or replace function public.allocate_cod_obligation_to_parcel(
  p_cod_obligation_id uuid,
  p_parcel_id uuid,
  p_expected_amount numeric(12,2),
  p_idempotency_key text
)
returns table(
  allocation_id uuid,
  cod_obligation_id uuid,
  parcel_id uuid,
  expected_amount numeric(12,2)
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_obligation public.cod_obligations%rowtype;
  v_parcel public.parcels%rowtype;
  v_allocation public.cod_obligation_allocations%rowtype;
  v_claim record;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then
    raise exception using errcode='42501', message='Authenticated operational role required';
  end if;
  if p_cod_obligation_id is null or p_parcel_id is null then
    raise exception using errcode='22023', message='COD obligation ID and parcel ID are required';
  end if;
  if p_expected_amount is null or p_expected_amount < 0 or p_expected_amount <> round(p_expected_amount, 2) then
    raise exception using errcode='22023', message='Expected COD amount must be non-negative and have at most two decimal places';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_claim := public.claim_command_idempotency(
    'allocate_cod_obligation_to_parcel',
    p_idempotency_key,
    md5(concat_ws('|', p_cod_obligation_id::text, p_parcel_id::text, p_expected_amount::text))
  );

  if not v_claim.is_new then
    return query
      select
        (v_claim.result->>'allocation_id')::uuid,
        (v_claim.result->>'cod_obligation_id')::uuid,
        (v_claim.result->>'parcel_id')::uuid,
        (v_claim.result->>'expected_amount')::numeric(12,2);
    return;
  end if;

  select * into v_obligation
  from public.cod_obligations
  where id = p_cod_obligation_id
  for update;
  if not found then
    raise exception using errcode='P0002', message='COD obligation not found';
  end if;
  if v_obligation.state in ('Voided','Closed') then
    raise exception using errcode='P0001', message='COD obligation is not eligible for parcel allocation';
  end if;

  select * into v_parcel
  from public.parcels
  where id = p_parcel_id
  for update;
  if not found then
    raise exception using errcode='P0002', message='Parcel not found';
  end if;
  if v_parcel.order_id <> v_obligation.order_id then
    raise exception using errcode='P0001', message='Parcel does not belong to the COD obligation order';
  end if;
  if v_parcel.state = 'Cancelled' then
    raise exception using errcode='P0001', message='Cancelled parcel is not eligible for COD allocation';
  end if;

  select * into v_allocation
  from public.cod_obligation_allocations
  where cod_obligation_id = p_cod_obligation_id
    and parcel_id = p_parcel_id
  for update;

  if found then
    if v_allocation.expected_amount <> p_expected_amount then
      raise exception using errcode='23505', message='COD allocation already exists for this obligation and parcel with a different amount';
    end if;
  else
    insert into public.cod_obligation_allocations(cod_obligation_id, parcel_id, expected_amount)
    values (p_cod_obligation_id, p_parcel_id, p_expected_amount)
    returning * into v_allocation;
  end if;

  v_result := jsonb_build_object(
    'allocation_id', v_allocation.id,
    'cod_obligation_id', v_allocation.cod_obligation_id,
    'parcel_id', v_allocation.parcel_id,
    'expected_amount', v_allocation.expected_amount
  );

  insert into public.order_events(order_id, parcel_id, event_type, performed_by, metadata)
  values (
    v_obligation.order_id,
    p_parcel_id,
    'CodObligationAllocatedToParcel',
    auth.uid(),
    jsonb_build_object('cod_obligation_id', p_cod_obligation_id, 'allocation_id', v_allocation.id, 'expected_amount', v_allocation.expected_amount)
  );

  insert into public.audit_logs(actor, action, entity_type, entity_id, after_data)
  values (auth.uid(), 'allocate_cod_obligation_to_parcel', 'cod_obligation_allocation', v_allocation.id, v_result);

  perform public.complete_command_idempotency('allocate_cod_obligation_to_parcel', p_idempotency_key, v_result);

  return query select v_allocation.id, v_allocation.cod_obligation_id, v_allocation.parcel_id, v_allocation.expected_amount;
end;
$$;

revoke all on function public.allocate_cod_obligation_to_parcel(uuid,uuid,numeric,text) from public, anon;
grant execute on function public.allocate_cod_obligation_to_parcel(uuid,uuid,numeric,text) to authenticated;

commit;
