-- P5-T099: Order item descriptions and quantities become immutable after confirmation.
-- Draft order editing remains supported; once an order leaves Draft its item set
-- cannot be inserted, updated, or deleted through direct table writes.

create or replace function public.prevent_confirmed_order_item_change()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_old_state text;
  v_new_state text;
begin
  if tg_op <> 'INSERT' then
    select lifecycle_state into v_old_state from public.orders where id = old.order_id;
    if v_old_state is null then
      raise exception using errcode='P0002', message='Original order not found';
    end if;
    if v_old_state <> 'Draft' then
      raise exception using errcode='P0001', message='Order items are immutable after confirmation';
    end if;
  end if;

  if tg_op <> 'DELETE' then
    select lifecycle_state into v_new_state from public.orders where id = new.order_id;
    if v_new_state is null then
      raise exception using errcode='P0002', message='Target order not found';
    end if;
    if v_new_state <> 'Draft' then
      raise exception using errcode='P0001', message='Order items are immutable after confirmation';
    end if;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists trg_order_items_immutable_after_confirmation on public.order_items;
create trigger trg_order_items_immutable_after_confirmation
before insert or update or delete on public.order_items
for each row
execute function public.prevent_confirmed_order_item_change();

revoke all on function public.prevent_confirmed_order_item_change() from public;
