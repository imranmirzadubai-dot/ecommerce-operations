begin;

-- P11-T167: establish the authoritative order-level COD obligation.
-- The obligation derives its expected amount from the immutable order original_amount.
-- Creation is transactional, idempotent, authenticated, and restricted to
-- orders that have reached Confirmed or a later non-cancelled lifecycle state.

create or replace function public.create_cod_obligation(
  p_order_id uuid,
  p_idempotency_key text
)
returns table(
  cod_obligation_id uuid,
  order_id uuid,
  expected_amount numeric(12,2),
  state text
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_order_state text;
  v_original_amount numeric(12,2);
  v_obligation public.cod_obligations%rowtype;
  v_claim record;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then
    raise exception using errcode='42501', message='Authenticated operational role required';
  end if;

  if p_order_id is null then
    raise exception using errcode='22023', message='Order ID is required';
  end if;

  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_claim := public.claim_command_idempotency(
    'create_cod_obligation',
    p_idempotency_key,
    md5(coalesce(p_order_id::text,''))
  );

  if not v_claim.is_new then
    return query
      select
        (v_claim.result->>'cod_obligation_id')::uuid,
        (v_claim.result->>'order_id')::uuid,
        (v_claim.result->>'expected_amount')::numeric(12,2),
        v_claim.result->>'state';
    return;
  end if;

  select o.lifecycle_state, o.original_amount
    into v_order_state, v_original_amount
  from public.orders o
  where o.id = p_order_id
  for update;

  if not found then
    raise exception using errcode='P0002', message='Order not found';
  end if;

  if v_order_state not in ('Confirmed','Active','Completed') then
    raise exception using errcode='P0001', message='COD obligation requires a Confirmed, Active, or Completed order';
  end if;

  select c.* into v_obligation
  from public.cod_obligations c
  where c.order_id = p_order_id
  for update;

  if not found then
    insert into public.cod_obligations(order_id, expected_amount, state)
    values(p_order_id, v_original_amount, 'Outstanding')
    returning * into v_obligation;
  end if;

  v_result := jsonb_build_object(
    'cod_obligation_id', v_obligation.id,
    'order_id', v_obligation.order_id,
    'expected_amount', v_obligation.expected_amount,
    'state', v_obligation.state
  );

  insert into public.order_events(order_id, event_type, performed_by, metadata)
  values(
    p_order_id,
    'CodObligationCreated',
    auth.uid(),
    jsonb_build_object(
      'cod_obligation_id', v_obligation.id,
      'expected_amount', v_obligation.expected_amount,
      'state', v_obligation.state
    )
  );

  insert into public.audit_logs(actor, action, entity_type, entity_id, after_data)
  values(auth.uid(), 'create_cod_obligation', 'cod_obligation', v_obligation.id, v_result);

  perform public.complete_command_idempotency('create_cod_obligation', p_idempotency_key, v_result);

  return query
    select v_obligation.id, v_obligation.order_id, v_obligation.expected_amount, v_obligation.state;
end;
$$;

revoke all on function public.create_cod_obligation(uuid,text) from public;
grant execute on function public.create_cod_obligation(uuid,text) to authenticated;

commit;
