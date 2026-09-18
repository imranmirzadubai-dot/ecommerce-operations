begin;

-- P11-T172: derive the COD receipt expected-amount snapshot from the
-- authoritative parcel allocation. The client supplies only the receipt
-- identity and collected amount; it cannot choose the financial snapshot.

drop function if exists public.record_cod_receipt(uuid, uuid, numeric, numeric, text);

create or replace function public.record_cod_receipt(
  p_cod_obligation_id uuid,
  p_parcel_id uuid,
  p_received_amount numeric(12,2),
  p_idempotency_key text
)
returns table(
  cod_receipt_id uuid,
  cod_obligation_id uuid,
  parcel_id uuid,
  expected_amount_snapshot numeric(12,2),
  received_amount numeric(12,2),
  state text,
  received_at timestamptz,
  received_by uuid
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_obligation public.cod_obligations%rowtype;
  v_parcel public.parcels%rowtype;
  v_allocation public.cod_obligation_allocations%rowtype;
  v_receipt public.cod_receipts%rowtype;
  v_claim record;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then
    raise exception using errcode='42501', message='Authenticated operational role required';
  end if;

  if p_cod_obligation_id is null then
    raise exception using errcode='22023', message='COD obligation ID is required';
  end if;

  if p_parcel_id is null then
    raise exception using errcode='22023', message='Parcel ID is required';
  end if;

  if p_received_amount is null or p_received_amount < 0 or p_received_amount <> round(p_received_amount, 2) then
    raise exception using errcode='22023', message='Received amount must be non-negative with at most two decimal places';
  end if;

  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_claim := public.claim_command_idempotency(
    'record_cod_receipt',
    p_idempotency_key,
    md5(concat_ws('|', p_cod_obligation_id::text, p_parcel_id::text, p_received_amount::text))
  );

  if not v_claim.is_new then
    return query
      select
        (v_claim.result->>'cod_receipt_id')::uuid,
        (v_claim.result->>'cod_obligation_id')::uuid,
        (v_claim.result->>'parcel_id')::uuid,
        (v_claim.result->>'expected_amount_snapshot')::numeric(12,2),
        (v_claim.result->>'received_amount')::numeric(12,2),
        v_claim.result->>'state',
        (v_claim.result->>'received_at')::timestamptz,
        (v_claim.result->>'received_by')::uuid;
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
    raise exception using errcode='P0001', message='COD receipt cannot be recorded for a Voided or Closed obligation';
  end if;

  select * into v_parcel
  from public.parcels
  where id = p_parcel_id
  for update;

  if not found then
    raise exception using errcode='P0002', message='Parcel not found';
  end if;

  if v_parcel.order_id <> v_obligation.order_id then
    raise exception using errcode='23514', message='Parcel does not belong to the COD obligation order';
  end if;

  if v_parcel.state = 'Cancelled' then
    raise exception using errcode='P0001', message='COD receipt cannot be recorded for a cancelled parcel';
  end if;

  -- The allocation is the sole authoritative source for the expected amount.
  select * into v_allocation
  from public.cod_obligation_allocations
  where cod_obligation_id = p_cod_obligation_id
    and parcel_id = p_parcel_id
  for update;

  if not found then
    raise exception using errcode='P0002', message='COD expected amount allocation not found for parcel';
  end if;

  select * into v_receipt
  from public.cod_receipts
  where parcel_id = p_parcel_id
  for update;

  if found then
    if v_receipt.cod_obligation_id = p_cod_obligation_id
       and v_receipt.expected_amount_snapshot = v_allocation.expected_amount
       and v_receipt.received_amount = p_received_amount then
      v_result := jsonb_build_object(
        'cod_receipt_id', v_receipt.id,
        'cod_obligation_id', v_receipt.cod_obligation_id,
        'parcel_id', v_receipt.parcel_id,
        'expected_amount_snapshot', v_receipt.expected_amount_snapshot,
        'received_amount', v_receipt.received_amount,
        'state', v_receipt.state,
        'received_at', v_receipt.received_at,
        'received_by', v_receipt.received_by
      );
      perform public.complete_command_idempotency('record_cod_receipt', p_idempotency_key, v_result);
      return query select v_receipt.id, v_receipt.cod_obligation_id, v_receipt.parcel_id,
        v_receipt.expected_amount_snapshot, v_receipt.received_amount, v_receipt.state,
        v_receipt.received_at, v_receipt.received_by;
      return;
    end if;
    raise exception using errcode='23505', message='A COD receipt already exists for this parcel';
  end if;

  insert into public.cod_receipts(
    cod_obligation_id,
    parcel_id,
    expected_amount_snapshot,
    received_amount,
    state,
    received_at,
    received_by
  )
  values(
    p_cod_obligation_id,
    p_parcel_id,
    v_allocation.expected_amount,
    p_received_amount,
    'Received',
    now(),
    auth.uid()
  )
  returning * into v_receipt;

  v_result := jsonb_build_object(
    'cod_receipt_id', v_receipt.id,
    'cod_obligation_id', v_receipt.cod_obligation_id,
    'parcel_id', v_receipt.parcel_id,
    'expected_amount_snapshot', v_receipt.expected_amount_snapshot,
    'received_amount', v_receipt.received_amount,
    'state', v_receipt.state,
    'received_at', v_receipt.received_at,
    'received_by', v_receipt.received_by
  );

  insert into public.order_events(order_id, parcel_id, event_type, performed_by, metadata)
  values(
    v_obligation.order_id,
    p_parcel_id,
    'CodReceiptRecorded',
    auth.uid(),
    jsonb_build_object(
      'cod_receipt_id', v_receipt.id,
      'cod_obligation_id', v_receipt.cod_obligation_id,
      'expected_amount_snapshot', v_receipt.expected_amount_snapshot,
      'received_amount', v_receipt.received_amount,
      'state', v_receipt.state
    )
  );

  insert into public.audit_logs(actor, action, entity_type, entity_id, after_data)
  values(auth.uid(), 'record_cod_receipt', 'cod_receipt', v_receipt.id, v_result);

  perform public.complete_command_idempotency('record_cod_receipt', p_idempotency_key, v_result);

  return query
    select v_receipt.id, v_receipt.cod_obligation_id, v_receipt.parcel_id,
      v_receipt.expected_amount_snapshot, v_receipt.received_amount, v_receipt.state,
      v_receipt.received_at, v_receipt.received_by;
end;
$$;

revoke all on function public.record_cod_receipt(uuid,uuid,numeric,text) from public, anon;
grant execute on function public.record_cod_receipt(uuid,uuid,numeric,text) to authenticated;

commit;
