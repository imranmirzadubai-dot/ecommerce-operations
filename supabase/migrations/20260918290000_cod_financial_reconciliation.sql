begin;

-- P11-T180: authoritative read-only COD/financial reconciliation.
-- Reconciliation combines the immutable commercial amount, append-only
-- financial adjustments, parcel COD allocation and immutable COD receipts.
-- It does not mutate transactional state; corrections continue through the
-- existing explicit financial/COD commands.
create or replace function public.get_cod_financial_reconciliation(
  p_order_id uuid
)
returns table (
  order_id uuid,
  original_amount numeric(12,2),
  adjustment_total numeric(12,2),
  effective_amount numeric(12,2),
  cod_expected_amount numeric(12,2),
  allocated_expected_amount numeric(12,2),
  received_amount numeric(12,2),
  outstanding_amount numeric(12,2),
  receipt_variance numeric(12,2),
  unresolved_exception_count bigint,
  unreceived_allocation_count bigint,
  reconciliation_state text
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_original_amount numeric(12,2);
  v_adjustment_total numeric(12,2);
  v_cod_expected numeric(12,2);
  v_allocated numeric(12,2);
  v_received numeric(12,2);
  v_receipt_variance numeric(12,2);
  v_exception_count bigint;
  v_unreceived_count bigint;
  v_effective numeric(12,2);
begin
  if auth.uid() is null or public.app_role() <> 'admin' then
    raise exception using errcode='42501', message='Admin role required for COD/financial reconciliation';
  end if;

  if p_order_id is null then
    raise exception using errcode='22023', message='Order ID is required';
  end if;

  select o.original_amount
    into v_original_amount
  from public.orders o
  where o.id = p_order_id;

  if not found then
    raise exception using errcode='P0002', message='Order not found';
  end if;

  select coalesce(sum(fa.delta_amount), 0)::numeric(12,2)
    into v_adjustment_total
  from public.financial_adjustments fa
  where fa.order_id = p_order_id;

  v_effective := round(v_original_amount + v_adjustment_total, 2)::numeric(12,2);

  select coalesce(max(co.expected_amount), 0)::numeric(12,2)
    into v_cod_expected
  from public.cod_obligations co
  where co.order_id = p_order_id;

  select coalesce(sum(ca.expected_amount), 0)::numeric(12,2)
    into v_allocated
  from public.cod_obligation_allocations ca
  join public.cod_obligations co on co.id = ca.cod_obligation_id
  where co.order_id = p_order_id;

  select coalesce(sum(cr.received_amount), 0)::numeric(12,2),
         coalesce(sum(cr.received_amount - cr.expected_amount_snapshot), 0)::numeric(12,2),
         count(*) filter (where cr.state = 'Exception')
    into v_received, v_receipt_variance, v_exception_count
  from public.cod_receipts cr
  join public.cod_obligations co on co.id = cr.cod_obligation_id
  where co.order_id = p_order_id;

  select count(*)
    into v_unreceived_count
  from public.cod_obligation_allocations ca
  join public.cod_obligations co on co.id = ca.cod_obligation_id
  left join public.cod_receipts cr on cr.cod_obligation_id = ca.cod_obligation_id
                                   and cr.parcel_id = ca.parcel_id
  where co.order_id = p_order_id
    and cr.id is null;

  order_id := p_order_id;
  original_amount := v_original_amount;
  adjustment_total := v_adjustment_total;
  effective_amount := v_effective;
  cod_expected_amount := v_cod_expected;
  allocated_expected_amount := v_allocated;
  received_amount := v_received;
  outstanding_amount := round(v_effective - v_received, 2)::numeric(12,2);
  receipt_variance := v_receipt_variance;
  unresolved_exception_count := v_exception_count;
  unreceived_allocation_count := v_unreceived_count;

  if v_exception_count > 0 then
    reconciliation_state := 'Exception';
  elsif v_unreceived_count > 0 or v_allocated <> v_cod_expected then
    reconciliation_state := 'Pending';
  elsif v_received = v_effective then
    reconciliation_state := 'Reconciled';
  elsif v_received < v_effective then
    reconciliation_state := 'Outstanding';
  else
    reconciliation_state := 'Overcollected';
  end if;

  return next;
end;
$$;

revoke all on function public.get_cod_financial_reconciliation(uuid) from public, anon;
grant execute on function public.get_cod_financial_reconciliation(uuid) to authenticated;

commit;
