begin;

-- T058 verification: active parcel allocations cannot exceed the ordered quantity.
-- Uses direct SQL assertions so the test remains runnable on staging without pgTAP.

create temporary table t058_ctx (
  order_id uuid,
  order_item_id uuid,
  parcel_a uuid,
  parcel_b uuid,
  shipper_id uuid,
  actor_id uuid
);

with actor as (
  select id as actor_id from auth.users limit 1
), shipper as (
  insert into public.shippers(name)
  values ('T058 Test Shipper')
  on conflict (name) do update set name = excluded.name
  returning id
), customer as (
  insert into public.customers(name, phone, normalized_phone)
  values ('T058 Test Customer', '+971500000058', '+971500000058')
  on conflict (normalized_phone) do update set name = excluded.name
  returning id
), ord as (
  insert into public.orders(customer_id, original_amount, created_by)
  select customer.id, 100.00, actor.actor_id from customer cross join actor
  returning id
), item as (
  insert into public.order_items(order_id, line_no, description, quantity)
  select ord.id, 1, 'T058 Test Item', 3 from ord
  returning id, order_id
), parcels as (
  insert into public.parcels(order_id, barcode)
  select item.order_id, 'PCL-T058-' || row_number() over ()
  from item cross join generate_series(1,2)
  returning id, order_id, parcel_number
)
insert into t058_ctx(order_id, order_item_id, parcel_a, parcel_b, shipper_id, actor_id)
select item.order_id, item.id,
       min(parcels.id), max(parcels.id), shipper.id, actor.actor_id
from item cross join parcels cross join shipper cross join actor
group by item.order_id, item.id, shipper.id, actor.actor_id;

update public.parcels p
set shipper_id = c.shipper_id
from t058_ctx c
where p.id in (c.parcel_a, c.parcel_b);

-- Two allocations totaling the ordered quantity are valid.
insert into public.parcel_items(parcel_id, order_item_id, quantity)
select parcel_a, order_item_id, 1 from t058_ctx;
insert into public.parcel_items(parcel_id, order_item_id, quantity)
select parcel_b, order_item_id, 2 from t058_ctx;

-- An additional active allocation must fail because 1 + 2 + 1 > 3.
do $$
begin
  begin
    insert into public.parcel_items(parcel_id, order_item_id, quantity)
    select parcel_a, order_item_id, 1 from t058_ctx;
    raise exception 'T058 expected allocation-overflow insert to fail';
  exception when check_violation then
    null;
  end;
end;
$$;

-- Historical release must not consume the active allocation ceiling.
update public.parcel_items
set allocation_state = 'Released'
where id = (select min(id) from public.parcel_items pi join t058_ctx c on pi.order_item_id = c.order_item_id);

insert into public.parcel_items(parcel_id, order_item_id, quantity)
select parcel_a, order_item_id, 1 from t058_ctx;

rollback;
