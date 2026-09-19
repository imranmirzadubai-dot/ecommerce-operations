-- P13-T201: Implement operational report views.
-- Read-only projections of authoritative operational data; no competing business state.

create or replace view public.report_orders
with (security_invoker = true)
as
select
  o.id as order_id,
  o.order_number,
  o.order_date,
  o.customer_id,
  c.customer_code,
  c.name as customer_name,
  c.city,
  o.currency_code,
  o.original_amount,
  o.lifecycle_state,
  count(distinct p.id)::bigint as parcel_count,
  count(distinct p.id) filter (where p.state = 'Delivered')::bigint as delivered_parcel_count,
  count(distinct p.id) filter (where p.state = 'RTO')::bigint as rto_parcel_count,
  count(distinct p.id) filter (where p.state = 'Lost')::bigint as lost_parcel_count,
  count(distinct p.id) filter (where p.state = 'Damaged')::bigint as damaged_parcel_count,
  o.created_at,
  o.updated_at
from public.orders o
join public.customers c on c.id = o.customer_id
left join public.parcels p on p.order_id = o.id
group by
  o.id, o.order_number, o.order_date, o.customer_id, c.customer_code,
  c.name, c.city, o.currency_code, o.original_amount, o.lifecycle_state,
  o.created_at, o.updated_at;

create or replace view public.report_parcel_delivery
with (security_invoker = true)
as
select
  p.id as parcel_id,
  p.parcel_number,
  p.barcode,
  p.order_id,
  o.order_number,
  p.state as parcel_state,
  p.shipper_id,
  s.name as shipper_name,
  p.tracking_id,
  p.dispatch_at,
  d.outcome as latest_outcome,
  d.occurred_at as latest_outcome_at,
  r.received_amount as delivered_amount,
  r.received_at as collected_at,
  p.created_at,
  p.updated_at
from public.parcels p
join public.orders o on o.id = p.order_id
left join public.shippers s on s.id = p.shipper_id
left join lateral (
  select d1.outcome, d1.occurred_at
  from public.delivery_outcomes d1
  where d1.parcel_id = p.id
  order by d1.occurred_at desc, d1.id desc
  limit 1
) d on true
left join public.cod_receipts r on r.parcel_id = p.id;

create or replace view public.report_customer_activity
with (security_invoker = true)
as
select
  c.id as customer_id,
  c.customer_code,
  c.name as customer_name,
  c.normalized_phone,
  c.city,
  count(o.id)::bigint as order_count,
  min(o.order_date) as first_order_date,
  max(o.order_date) as latest_order_date,
  coalesce(sum(o.original_amount), 0::numeric(12,2)) as original_order_amount_total,
  count(o.id) filter (where o.lifecycle_state in ('Confirmed','Active'))::bigint as current_open_order_count
from public.customers c
left join public.orders o on o.customer_id = c.id
group by c.id, c.customer_code, c.name, c.normalized_phone, c.city;

revoke all on public.report_orders, public.report_parcel_delivery,
  public.report_customer_activity from anon;
grant select on public.report_orders, public.report_parcel_delivery,
  public.report_customer_activity to authenticated;
