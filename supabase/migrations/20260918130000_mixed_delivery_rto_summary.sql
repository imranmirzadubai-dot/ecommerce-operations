-- P10-T159: order-level mixed Delivered/RTO reconciliation summary.
-- The summary is derived from the canonical item-level reconciliation view;
-- it introduces no editable operational totals or mutation path.

create or replace view public.order_delivery_rto_summary as
select
  r.order_id,
  count(*)::integer as order_item_count,
  coalesce(sum(r.ordered_quantity), 0)::integer as ordered_quantity,
  coalesce(sum(r.delivered_quantity), 0)::integer as delivered_quantity,
  coalesce(sum(r.rto_quantity), 0)::integer as rto_quantity,
  coalesce(sum(r.unresolved_quantity), 0)::integer as unresolved_quantity,
  (
    coalesce(sum(r.delivered_quantity), 0) > 0
    and coalesce(sum(r.rto_quantity), 0) > 0
  ) as is_mixed_delivered_rto,
  (
    coalesce(sum(r.delivered_quantity), 0) + coalesce(sum(r.rto_quantity), 0) > 0
    and coalesce(sum(r.delivered_quantity), 0) + coalesce(sum(r.rto_quantity), 0)
      < coalesce(sum(r.ordered_quantity), 0)
  ) as is_partially_resolved
from public.order_item_delivery_reconciliation r
group by r.order_id;

comment on view public.order_delivery_rto_summary is
  'P10-T159: derives order-level Delivered/RTO quantities and mixed/partial indicators from the canonical item-level reconciliation view.';

revoke all on public.order_delivery_rto_summary from anon;
grant select on public.order_delivery_rto_summary to authenticated;
