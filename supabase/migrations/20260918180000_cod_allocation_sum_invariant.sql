begin;

-- P11-T169: enforce that parcel expected COD allocations never exceed the
-- order-level obligation and must exactly reconcile before an obligation is
-- marked Received or Closed. Partial allocations remain valid while an
-- obligation is Outstanding, Partially Received, or Exception.
create or replace function public.enforce_cod_allocation_sum_invariant()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_obligation public.cod_obligations%rowtype;
  v_allocated numeric(12,2);
begin
  if tg_table_name = 'cod_obligations' then
    select * into v_obligation
    from public.cod_obligations
    where id = new.id
    for update;
  else
    select * into v_obligation
    from public.cod_obligations
    where id = coalesce(new.cod_obligation_id, old.cod_obligation_id)
    for update;
  end if;

  if not found then
    raise exception using errcode='P0002', message='COD obligation not found for allocation reconciliation';
  end if;

  select coalesce(sum(expected_amount), 0)::numeric(12,2)
    into v_allocated
  from public.cod_obligation_allocations
  where cod_obligation_id = v_obligation.id;

  -- Never permit parcel allocations to exceed the authoritative order-level
  -- COD obligation, including under concurrent allocation attempts.
  if v_allocated > v_obligation.expected_amount then
    raise exception using
      errcode='23514',
      message=format('Parcel COD allocation total %s exceeds obligation %s', v_allocated, v_obligation.expected_amount);
  end if;

  -- A received or closed obligation is only valid when every parcel's
  -- expected COD allocation reconciles exactly to the order obligation.
  if v_obligation.state in ('Received','Closed')
     and v_allocated <> v_obligation.expected_amount then
    raise exception using
      errcode='23514',
      message=format('Parcel COD allocation total %s must equal obligation %s before state %s', v_allocated, v_obligation.expected_amount, v_obligation.state);
  end if;

  return coalesce(new, old);
end;
$$;

create or replace trigger cod_obligation_allocations_sum_invariant
  after insert or update or delete on public.cod_obligation_allocations
  for each row
  execute function public.enforce_cod_allocation_sum_invariant();

create or replace trigger cod_obligations_sum_invariant
  after update of expected_amount, state on public.cod_obligations
  for each row
  when (old.expected_amount is distinct from new.expected_amount or old.state is distinct from new.state)
  execute function public.enforce_cod_allocation_sum_invariant();

revoke all on function public.enforce_cod_allocation_sum_invariant() from public, anon, authenticated;

grant execute on function public.enforce_cod_allocation_sum_invariant() to authenticated;

commit;
