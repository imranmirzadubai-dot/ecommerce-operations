begin;

-- P11-T177: authoritative effective commercial amount calculation.
-- Effective amount is derived from the immutable order original amount plus
-- the append-only financial adjustment ledger.
create or replace function public.get_effective_order_amount(
  p_order_id uuid
)
returns numeric(12,2)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_original_amount numeric(12,2);
  v_adjustment_total numeric(12,2);
begin
  if auth.uid() is null or public.app_role() <> 'admin' then
    raise exception using errcode='42501', message='Admin role required to calculate effective order amount';
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

  select coalesce(sum(fa.delta_amount), 0::numeric(12,2))
    into v_adjustment_total
  from public.financial_adjustments fa
  where fa.order_id = p_order_id;

  return round(v_original_amount + v_adjustment_total, 2)::numeric(12,2);
end;
$$;

revoke all on function public.get_effective_order_amount(uuid) from public, anon;
grant execute on function public.get_effective_order_amount(uuid) to authenticated;

commit;
