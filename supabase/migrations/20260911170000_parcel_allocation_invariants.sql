-- E-Commerce Operations MVP v4.0
-- P2-T039: Formalize parcel allocation invariants.
-- Active allocations are authoritative reservations against ordered integer quantity.
-- Historical Released/Reversed rows are retained and do not consume active quantity.

create or replace function public.assert_order_item_allocation_invariant(p_order_item_id uuid)
returns void
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_ordered_quantity integer;
  v_allocated_quantity integer;
begin
  if p_order_item_id is null then
    raise exception using errcode='22023', message='Order item is required';
  end if;

  -- Serialize all allocations for the same order item so concurrent commands
  -- cannot both observe spare quantity and commit an over-allocation.
  select oi.quantity
    into v_ordered_quantity
  from public.order_items oi
  where oi.id=p_order_item_id
  for update;

  if not found then
    raise exception using errcode='P0002', message='Order item not found';
  end if;

  select coalesce(sum(pi.quantity),0)::integer
    into v_allocated_quantity
  from public.parcel_items pi
  join public.parcels p on p.id=pi.parcel_id
  where pi.order_item_id=p_order_item_id
    and pi.allocation_state='Allocated';

  if v_allocated_quantity>v_ordered_quantity then
    raise exception using
      errcode='23514',
      message=format(
        'Parcel allocation exceeds ordered quantity for order item %s: allocated=%s ordered=%s',
        p_order_item_id,v_allocated_quantity,v_ordered_quantity
      );
  end if;
end;
$$;

revoke all on function public.assert_order_item_allocation_invariant(uuid) from public;
grant execute on function public.assert_order_item_allocation_invariant(uuid) to authenticated;

create or replace function public.validate_parcel_item_allocation()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
begin
  -- The invariant is meaningful for both the old and new order item when an
  -- existing allocation is moved. NULL is not permitted by the table schema.
  if tg_op='DELETE' then
    perform public.assert_order_item_allocation_invariant(old.order_item_id);
    return old;
  end if;

  if tg_op='UPDATE' and old.order_item_id is distinct from new.order_item_id then
    if old.order_item_id<new.order_item_id then
      perform public.assert_order_item_allocation_invariant(old.order_item_id);
      perform public.assert_order_item_allocation_invariant(new.order_item_id);
    else
      perform public.assert_order_item_allocation_invariant(new.order_item_id);
      perform public.assert_order_item_allocation_invariant(old.order_item_id);
    end if;
  else
    perform public.assert_order_item_allocation_invariant(new.order_item_id);
  end if;

  return new;
end;
$$;

revoke all on function public.validate_parcel_item_allocation() from public;

drop trigger if exists trg_validate_parcel_item_allocation on public.parcel_items;
create constraint trigger trg_validate_parcel_item_allocation
after insert or update or delete on public.parcel_items
deferrable initially deferred
for each row execute function public.validate_parcel_item_allocation();

-- Physical-state transitions must never create a terminal quantity greater than
-- the original ordered quantity. Active allocations remain counted even after a
-- parcel becomes terminal; they are not silently released by a delivery outcome.
create or replace function public.assert_order_item_physical_outcome_invariant(p_order_item_id uuid)
returns void
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_ordered_quantity integer;
  v_terminal_quantity integer;
begin
  select oi.quantity
    into v_ordered_quantity
  from public.order_items oi
  where oi.id=p_order_item_id
  for update;

  if not found then
    raise exception using errcode='P0002', message='Order item not found';
  end if;

  select coalesce(sum(pi.quantity),0)::integer
    into v_terminal_quantity
  from public.parcel_items pi
  join public.parcels p on p.id=pi.parcel_id
  where pi.order_item_id=p_order_item_id
    and pi.allocation_state='Allocated'
    and p.state in ('Delivered','RTO','Lost','Damaged');

  if v_terminal_quantity>v_ordered_quantity then
    raise exception using
      errcode='23514',
      message=format(
        'Terminal parcel quantity exceeds ordered quantity for order item %s: terminal=%s ordered=%s',
        p_order_item_id,v_terminal_quantity,v_ordered_quantity
      );
  end if;
end;
$$;

revoke all on function public.assert_order_item_physical_outcome_invariant(uuid) from public;
grant execute on function public.assert_order_item_physical_outcome_invariant(uuid) to authenticated;

create or replace function public.validate_parcel_state_allocation()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_item_id uuid;
begin
  if tg_op='UPDATE' and old.state is not distinct from new.state then
    return new;
  end if;

  for v_item_id in
    select distinct pi.order_item_id
    from public.parcel_items pi
    where pi.parcel_id=new.id
      and pi.allocation_state='Allocated'
    order by pi.order_item_id
  loop
    perform public.assert_order_item_physical_outcome_invariant(v_item_id);
  end loop;

  return new;
end;
$$;

revoke all on function public.validate_parcel_state_allocation() from public;

drop trigger if exists trg_validate_parcel_state_allocation on public.parcels;
create constraint trigger trg_validate_parcel_state_allocation
after insert or update of state on public.parcels
deferrable initially deferred
for each row execute function public.validate_parcel_state_allocation();
