begin;

-- P11-T174: resolve a COD receipt variance through an Admin-only,
-- append-only financial adjustment. The original receipt remains immutable.
create or replace function public.resolve_cod_exception(
  p_cod_receipt_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns table(
  financial_adjustment_id uuid,
  cod_receipt_id uuid,
  cod_obligation_id uuid,
  parcel_id uuid,
  delta_amount numeric(12,2),
  obligation_state text
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_receipt public.cod_receipts%rowtype;
  v_obligation public.cod_obligations%rowtype;
  v_adjustment public.financial_adjustments%rowtype;
  v_claim record;
  v_result jsonb;
  v_delta numeric(12,2);
  v_unresolved bigint;
  v_unreceived bigint;
begin
  if auth.uid() is null or public.app_role() <> 'admin' then
    raise exception using errcode='42501', message='Admin role required to resolve COD exceptions';
  end if;
  if p_cod_receipt_id is null then raise exception using errcode='22023', message='COD receipt ID is required'; end if;
  if btrim(coalesce(p_reason,'')) = '' then raise exception using errcode='22023', message='Resolution reason is required'; end if;
  if btrim(coalesce(p_reason,'')) <> p_reason or length(p_reason) > 500 then raise exception using errcode='22023', message='Resolution reason must be trimmed and at most 500 characters'; end if;
  if btrim(coalesce(p_idempotency_key,'')) = '' then raise exception using errcode='22023', message='Idempotency key is required'; end if;

  v_claim := public.claim_command_idempotency('resolve_cod_exception', p_idempotency_key, md5(concat_ws('|', p_cod_receipt_id::text, p_reason)));
  if not v_claim.is_new then
    return query select
      (v_claim.result->>'financial_adjustment_id')::uuid,
      (v_claim.result->>'cod_receipt_id')::uuid,
      (v_claim.result->>'cod_obligation_id')::uuid,
      (v_claim.result->>'parcel_id')::uuid,
      (v_claim.result->>'delta_amount')::numeric(12,2),
      v_claim.result->>'obligation_state';
    return;
  end if;

  select * into v_receipt from public.cod_receipts where id = p_cod_receipt_id for update;
  if not found then raise exception using errcode='P0002', message='COD receipt not found'; end if;
  if v_receipt.state <> 'Exception' then raise exception using errcode='P0001', message='Only COD receipts in Exception state can be resolved'; end if;

  select * into v_obligation from public.cod_obligations where id = v_receipt.cod_obligation_id for update;
  if not found then raise exception using errcode='P0002', message='COD obligation not found'; end if;
  if v_obligation.state in ('Voided','Closed') then raise exception using errcode='P0001', message='COD exception cannot be resolved for a Voided or Closed obligation'; end if;

  select * into v_adjustment from public.financial_adjustments
  where cod_receipt_id = v_receipt.id and adjustment_type = 'COD_EXCEPTION_RESOLUTION' for update;
  if found then
    if v_adjustment.reason = p_reason then
      v_result := jsonb_build_object('financial_adjustment_id',v_adjustment.id,'cod_receipt_id',v_receipt.id,'cod_obligation_id',v_receipt.cod_obligation_id,'parcel_id',v_receipt.parcel_id,'delta_amount',v_adjustment.delta_amount,'obligation_state',v_obligation.state);
      perform public.complete_command_idempotency('resolve_cod_exception', p_idempotency_key, v_result);
      return query select v_adjustment.id,v_receipt.id,v_receipt.cod_obligation_id,v_receipt.parcel_id,v_adjustment.delta_amount,v_obligation.state;
      return;
    end if;
    raise exception using errcode='23505', message='COD exception has already been resolved';
  end if;

  -- Effective amount = original amount + append-only adjustments.
  v_delta := (v_receipt.received_amount - v_receipt.expected_amount_snapshot)::numeric(12,2);
  insert into public.financial_adjustments(order_id,adjustment_type,delta_amount,reason,performed_by,parcel_id,cod_receipt_id)
  values(v_obligation.order_id,'COD_EXCEPTION_RESOLUTION',v_delta,p_reason,auth.uid(),v_receipt.parcel_id,v_receipt.id)
  returning * into v_adjustment;

  select count(*) into v_unreceived
  from public.cod_obligation_allocations a
  left join public.cod_receipts r on r.cod_obligation_id=a.cod_obligation_id and r.parcel_id=a.parcel_id
  where a.cod_obligation_id=v_obligation.id and r.id is null;

  select count(*) into v_unresolved
  from public.cod_receipts r
  where r.cod_obligation_id=v_obligation.id and r.state='Exception'
    and not exists (select 1 from public.financial_adjustments fa where fa.cod_receipt_id=r.id and fa.adjustment_type='COD_EXCEPTION_RESOLUTION');

  if v_unreceived=0 and v_unresolved=0 then
    update public.cod_obligations set state='Closed',closed_at=now(),closed_by=auth.uid() where id=v_obligation.id;
    v_obligation.state:='Closed';
  else
    update public.cod_obligations set state='Exception' where id=v_obligation.id;
    v_obligation.state:='Exception';
  end if;

  v_result := jsonb_build_object('financial_adjustment_id',v_adjustment.id,'cod_receipt_id',v_receipt.id,'cod_obligation_id',v_receipt.cod_obligation_id,'parcel_id',v_receipt.parcel_id,'delta_amount',v_adjustment.delta_amount,'obligation_state',v_obligation.state);
  insert into public.order_events(order_id,parcel_id,event_type,performed_by,metadata)
  values(v_obligation.order_id,v_receipt.parcel_id,'CodExceptionResolved',auth.uid(),v_result || jsonb_build_object('reason',p_reason));
  insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
  values(auth.uid(),'resolve_cod_exception','cod_receipt',v_receipt.id,jsonb_build_object('state',v_receipt.state,'received_amount',v_receipt.received_amount,'expected_amount_snapshot',v_receipt.expected_amount_snapshot),v_result || jsonb_build_object('reason',p_reason));
  perform public.complete_command_idempotency('resolve_cod_exception',p_idempotency_key,v_result);
  return query select v_adjustment.id,v_receipt.id,v_receipt.cod_obligation_id,v_receipt.parcel_id,v_adjustment.delta_amount,v_obligation.state;
end;
$$;

create unique index if not exists uq_financial_adjustments_cod_exception_resolution
  on public.financial_adjustments(cod_receipt_id)
  where adjustment_type = 'COD_EXCEPTION_RESOLUTION';

revoke all on function public.resolve_cod_exception(uuid,text,text) from public, anon;
grant execute on function public.resolve_cod_exception(uuid,text,text) to authenticated;

commit;
