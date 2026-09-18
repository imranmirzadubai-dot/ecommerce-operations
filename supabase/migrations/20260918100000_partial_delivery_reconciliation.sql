-- P10-T157: item-level partial delivery reconciliation.
-- Canonical quantities remain in order_items + parcel_items + parcel outcomes.
-- Delivered/RTO quantities are derived, not independently editable fields.

create or replace view public.order_item_delivery_reconciliation as
select
  oi.id as order_item_id,
  oi.order_id,
  oi.line_no,
  oi.description,
  oi.quantity as ordered_quantity,
  coalesce(sum(case when p.state = 'Delivered' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)::integer as delivered_quantity,
  coalesce(sum(case when p.state = 'RTO' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)::integer as rto_quantity,
  (
    oi.quantity
    - coalesce(sum(case when p.state = 'Delivered' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
    - coalesce(sum(case when p.state = 'RTO' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
  )::integer as unresolved_quantity,
  (
    coalesce(sum(case when p.state in ('Delivered','RTO') and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0) > 0
    and
    coalesce(sum(case when p.state in ('Delivered','RTO') and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0) < oi.quantity
  ) as is_partial
from public.order_items oi
left join public.parcel_items pi on pi.order_item_id = oi.id
left join public.parcels p on p.id = pi.parcel_id
where oi.quantity > 0
group by oi.id, oi.order_id, oi.line_no, oi.description, oi.quantity;

comment on view public.order_item_delivery_reconciliation is
  'P10-T157: derives delivered, RTO and unresolved item quantities from immutable order items, parcel allocations and parcel outcomes; supports partial delivery without competing editable totals.';

revoke all on public.order_item_delivery_reconciliation from anon;
grant select on public.order_item_delivery_reconciliation to authenticated;
