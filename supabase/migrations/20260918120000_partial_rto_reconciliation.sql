-- P10-T158: item-level partial RTO reconciliation.
-- RTO quantities remain derived from immutable order items, parcel allocations,
-- and parcel outcomes; no competing editable totals are introduced.

create or replace view public.order_item_rto_reconciliation as
select
  oi.id as order_item_id,
  oi.order_id,
  oi.line_no,
  oi.description,
  oi.quantity as ordered_quantity,
  coalesce(sum(case when pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)::integer as allocated_quantity,
  coalesce(sum(case when p.state = 'Delivered' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)::integer as delivered_quantity,
  coalesce(sum(case when p.state = 'RTO' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)::integer as rto_quantity,
  (
    coalesce(sum(case when pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
    - coalesce(sum(case when p.state = 'RTO' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
  )::integer as non_rto_allocated_quantity,
  (
    coalesce(sum(case when p.state = 'RTO' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0) > 0
    and
    coalesce(sum(case when p.state = 'RTO' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
      < coalesce(sum(case when pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
  ) as is_partial_rto
from public.order_items oi
left join public.parcel_items pi on pi.order_item_id = oi.id
left join public.parcels p on p.id = pi.parcel_id
where oi.quantity > 0
group by oi.id, oi.order_id, oi.line_no, oi.description, oi.quantity;

comment on view public.order_item_rto_reconciliation is
  'P10-T158: derives allocated, delivered, RTO and remaining non-RTO quantities per order item; identifies partial RTO without introducing editable reconciliation totals.';

revoke all on public.order_item_rto_reconciliation from anon;
grant select on public.order_item_rto_reconciliation to authenticated;
