begin;

-- P11-T178: prevent an adjustment from driving the authoritative effective
-- commercial amount below zero. The original amount remains immutable and
-- financial corrections remain append-only.
create or replace function public.create_financial_adjustment(
  p_order_id uuid,
  p_adjustment_type text,
  p_delta_amount numeric(12,2),
  p_reason text,
  p_parcel_id uuid,
  p_cod_receipt_id uuid,
  p_idempotency_key text
)
returns table(
  financial_adjustment_id uuid,
  order_id uuid,
  adjustment_type text,
  delta_amount numeric(12,2),
  reason text,
  parcel_id uuid,
  cod_receipt_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_order public.orders%rowtype;
  v_parcel public.parcels%rowtype;
  v_receipt public.cod_receipts%rowtype;
  v_adjustment public.financial_adjustments%rowtype;
  v_claim record;
  v_result jsonb;
  v_current_effective_amount numeric;
  v_resulting_amount numeric;
begin
  if auth.uid() is null or public.app_role() <> 'admin' then
    raise exception using errcode='42501', message='Admin role required to create financial adjustments';
  end if;

  if p_order_id is null then
    raise exception using errcode='22023', message='Order ID is required';
  end if;
  if btrim(coalesce(p_adjustment_type,'')) = '' or p_adjustment_type <> btrim(p_adjustment_type) or length(p_adjustment_type) > 100 then
    raise exception using errcode='22023', message='Adjustment type must be nonempty, trimmed, and at most 100 characters';
  end if;
  if p_delta_amount is null then
    raise exception using errcode='22023', message='Adjustment amount is required';
  end if;
  if btrim(coalesce(p_reason,'')) = '' or p_reason <> btrim(p_reason) or length(p_reason) > 500 then
    raise exception using errcode='22023', message='Adjustment reason must be nonempty, trimmed, and at most 500 characters';
  end if;
  if btrim(coalesce(p_idempotency_key,'')) = '' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_claim := public.claim_command_idempotency(
    'create_financial_adjustment',
    p_idempotency_key,
    md5(concat_ws('|', p_order_id::text, p_adjustment_type, p_delta_amount::text, p_reason, coalesce(p_parcel_id::text,''), coalesce(p_cod_receipt_id::text,'')))
  );

  if not v_claim.is_new then
    return query select
      (v_claim.result->>'financial_adjustment_id')::uuid,
      (v_claim.result->>'order_id')::uuid,
      v_claim.result->>'adjustment_type',
      (v_claim.result->>'delta_amount')::numeric(12,2),
      v_claim.result->>'reason',
      (v_claim.result->>'parcel_id')::uuid,
      (v_claim.result->>'cod_receipt_id')::uuid;
    return;
  end if;

  -- Lock the authoritative order before calculating the resulting amount.
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then raise exception using errcode='P0002', message='Order not found'; end if;

  -- Validate the resulting effective amount before appending the adjustment.
  select round(v_order.original_amount + coalesce(sum(fa.delta_amount), 0::numeric), 2)
    into v_current_effective_amount
  from public.financial_adjustments fa
  where fa.order_id = p_order_id;

  v_resulting_amount := v_current_effective_amount + p_delta_amount;
  if v_resulting_amount < 0 then
    raise exception using errcode='22023', message='Adjustment would make effective order amount negative';
  end if;

  if p_parcel_id is not null then
    select * into v_parcel from public.parcels where id = p_parcel_id for update;
    if not found then raise exception using errcode='P0002', message='Parcel not found'; end if;
    if v_parcel.order_id <> p_order_id then raise exception using errcode='23503', message='Parcel does not belong to order'; end if;
  end if;

  if p_cod_receipt_id is not null then
    select * into v_receipt from public.cod_receipts where id = p_cod_receipt_id for update;
    if not found then raise exception using errcode='P0002', message='COD receipt not found'; end if;
    if v_receipt.cod_obligation_id is null then raise exception using errcode='23503', message='COD receipt has no obligation'; end if;
    if not exists (select 1 from public.cod_obligations c where c.id = v_receipt.cod_obligation_id and c.order_id = p_order_id) then
      raise exception using errcode='23503', message='COD receipt does not belong to order';
    end if;
    if p_parcel_id is not null and v_receipt.parcel_id <> p_parcel_id then
      raise exception using errcode='23503', message='COD receipt does not belong to parcel';
    end if;
  end if;

  insert into public.financial_adjustments(
    order_id, adjustment_type, delta_amount, reason, performed_by, parcel_id, cod_receipt_id
  ) values (
    p_order_id, p_adjustment_type, p_delta_amount, p_reason, auth.uid(), p_parcel_id, p_cod_receipt_id
  ) returning * into v_adjustment;

  v_result := jsonb_build_object(
    'financial_adjustment_id', v_adjustment.id,
    'order_id', v_adjustment.order_id,
    'adjustment_type', v_adjustment.adjustment_type,
    'delta_amount', v_adjustment.delta_amount,
    'reason', v_adjustment.reason,
    'parcel_id', v_adjustment.parcel_id,
    'cod_receipt_id', v_adjustment.cod_receipt_id
  );

  insert into public.order_events(order_id, parcel_id, event_type, performed_by, metadata)
  values(p_order_id, p_parcel_id, 'FinancialAdjustmentCreated', auth.uid(), v_result);

  insert into public.audit_logs(actor, action, entity_type, entity_id, after_data)
  values(auth.uid(), 'create_financial_adjustment', 'financial_adjustment', v_adjustment.id, v_result);

  perform public.complete_command_idempotency('create_financial_adjustment', p_idempotency_key, v_result);

  return query select
    v_adjustment.id,
    v_adjustment.order_id,
    v_adjustment.adjustment_type,
    v_adjustment.delta_amount,
    v_adjustment.reason,
    v_adjustment.parcel_id,
    v_adjustment.cod_receipt_id;
end;
$$;

revoke all on function public.create_financial_adjustment(uuid,text,numeric,text,uuid,uuid,text) from public, anon;
grant execute on function public.create_financial_adjustment(uuid,text,numeric,text,uuid,uuid,text) to authenticated;

commit;
