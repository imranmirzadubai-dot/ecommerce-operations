begin;
set constraints all immediate;
select plan(6);

select ok((select format_type(a.atttypid,a.atttypmod)='integer'
  from pg_attribute a
  where a.attrelid='public.order_items'::regclass
    and a.attname='quantity'
    and not a.attisdropped),'order item quantity is INTEGER');

select ok((select format_type(a.atttypid,a.atttypmod)='integer'
  from pg_attribute a
  where a.attrelid='public.parcel_items'::regclass
    and a.attname='quantity'
    and not a.attisdropped),'parcel allocation quantity is INTEGER');

select ok((select exists(
  select 1 from pg_constraint c
  where c.conrelid='public.order_items'::regclass
    and pg_get_constraintdef(c.oid) like '%quantity > 0%'
)),'order item quantity has a positive-value constraint');

select ok((select exists(
  select 1 from pg_constraint c
  where c.conrelid='public.parcel_items'::regclass
    and pg_get_constraintdef(c.oid) like '%quantity > 0%'
)),'parcel allocation quantity has a positive-value constraint');

select has_function('public','assert_order_item_allocation_invariant',ARRAY['uuid'],'canonical allocation invariant helper exists');

select ok(exists(
  select 1 from pg_trigger
  where tgname='trg_validate_parcel_item_allocation'
),'parcel-item allocation trigger enforces the canonical invariant');

select * from finish();
rollback;
