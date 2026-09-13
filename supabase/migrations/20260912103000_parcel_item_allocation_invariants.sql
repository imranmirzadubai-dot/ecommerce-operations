begin;

-- T058: strengthen parcel-item allocation integrity.
-- The ordered quantity for an order item is the ceiling for all active
-- parcel allocations. Released/Reversed rows remain historical and do not
-- consume the active allocation ceiling.

create or replace function public.enforce_parcel_item_allocation_quantity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  ordered_qty integer;
  allocated_qty integer;
begin
  if new.allocation_state <> 'Allocated' then
    return new;
  end if;

  select oi.quantity
    into ordered_qty
  from public.order_items oi
  where oi.id = new.order_item_id
  for update;

  if ordered_qty is null then
    raise exception 'order item not found' using errcode = 'P0002';
  end if;

  select coalesce(sum(pi.quantity), 0)
    into allocated_qty
  from public.parcel_items pi
  where pi.order_item_id = new.order_item_id
    and pi.allocation_state = 'Allocated'
    and pi.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid);

  if allocated_qty + new.quantity > ordered_qty then
    raise exception 'parcel allocation exceeds ordered quantity' using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_parcel_item_allocation_quantity() from public;

drop trigger if exists trg_enforce_parcel_item_allocation_quantity on public.parcel_items;
create constraint trigger trg_enforce_parcel_item_allocation_quantity
  after insert or update of order_item_id, quantity, allocation_state
  on public.parcel_items
  deferrable initially deferred
  for each row
  execute function public.enforce_parcel_item_allocation_quantity();

commit;
