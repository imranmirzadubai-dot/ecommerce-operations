-- P10-T160: Lost/Damaged quantity accounting.
-- Terminal quantities are derived from canonical order-item allocations and
-- authoritative parcel states; no editable counters are introduced.

create or replace view public.order_item_terminal_reconciliation as
select
  oi.id as order_item_id,
  oi.order_id,
  oi.line_no,
  oi.description,
  oi.quantity as ordered_quantity,
  coalesce(sum(case when pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)::integer as allocated_quantity,
  coalesce(sum(case when p.state = 'Delivered' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)::integer as delivered_quantity,
  coalesce(sum(case when p.state = 'RTO' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)::integer as rto_quantity,
  coalesce(sum(case when p.state = 'Lost' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)::integer as lost_quantity,
  coalesce(sum(case when p.state = 'Damaged' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)::integer as damaged_quantity,
  (
    oi.quantity
    - coalesce(sum(case when p.state = 'Delivered' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
    - coalesce(sum(case when p.state = 'RTO' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
    - coalesce(sum(case when p.state = 'Lost' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
    - coalesce(sum(case when p.state = 'Damaged' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
  )::integer as unresolved_quantity,
  (
    coalesce(sum(case when p.state in ('Delivered','RTO','Lost','Damaged') and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
  )::integer as accounted_quantity,
  (
    coalesce(sum(case when p.state in ('Delivered','RTO','Lost','Damaged') and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0) > 0
    and (
      coalesce(sum(case when p.state = 'Lost' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
      + coalesce(sum(case when p.state = 'Damaged' and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
    ) > 0
  ) as has_lost_or_damaged,
  (
    coalesce(sum(case when p.state in ('Delivered','RTO','Lost','Damaged') and pi.allocation_state = 'Allocated' then pi.quantity else 0 end), 0)
    <= oi.quantity
  ) as terminal_quantity_within_ordered
from public.order_items oi
left join public.parcel_items pi on pi.order_item_id = oi.id
left join public.parcels p on p.id = pi.parcel_id
where oi.quantity > 0
group by oi.id, oi.order_id, oi.line_no, oi.description, oi.quantity;

comment on view public.order_item_terminal_reconciliation is
  'P10-T160: derives Delivered, RTO, Lost, Damaged, accounted and unresolved quantities per order item while preserving the ordered quantity as the invariant boundary.';

revoke all on public.order_item_terminal_reconciliation from anon;
grant select on public.order_item_terminal_reconciliation to authenticated;
