-- P5-T098: Original order amount becomes immutable when an order leaves Draft.
-- This is defense-in-depth for SECURITY DEFINER commands and future write paths.
-- Pre-confirmation Draft edits remain allowed; confirmation and all later states
-- cannot change the authoritative original commercial amount.

create or replace function public.prevent_confirmed_original_amount_change()
returns trigger
language plpgsql
set search_path=pg_catalog, public
as $$
begin
  if new.original_amount is distinct from old.original_amount
     and (old.lifecycle_state <> 'Draft' or new.lifecycle_state <> 'Draft') then
    raise exception using
      errcode='P0001',
      message='Original order amount is immutable after confirmation';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_original_amount_immutable on public.orders;
create trigger trg_orders_original_amount_immutable
before update of original_amount, lifecycle_state on public.orders
for each row
execute function public.prevent_confirmed_original_amount_change();

revoke all on function public.prevent_confirmed_original_amount_change() from public;
