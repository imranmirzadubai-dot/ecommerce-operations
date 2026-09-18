-- P10-T163: read-only order fulfillment summary projection.
-- Current parcel state remains authoritative; this view only projects operational
-- quantities/status and never writes lifecycle state.

create or replace view public.order_fulfillment_summary as
with parcel_rollup as (
  select
    p.order_id,
    count(*)::integer as parcel_count,
    count(*) filter (where p.state = 'Delivered')::integer as delivered_parcel_count,
    count(*) filter (where p.state = 'RTO')::integer as rto_parcel_count,
    count(*) filter (where p.state = 'Lost')::integer as lost_parcel_count,
    count(*) filter (where p.state = 'Damaged')::integer as damaged_parcel_count,
    count(*) filter (where not public.is_terminal_parcel_state(p.state))::integer as nonterminal_parcel_count
  from public.parcels p
  group by p.order_id
),
item_rollup as (
  select
    r.order_id,
    coalesce(sum(r.ordered_quantity), 0)::integer as ordered_quantity,
    coalesce(sum(r.delivered_quantity), 0)::integer as delivered_quantity,
    coalesce(sum(r.rto_quantity), 0)::integer as rto_quantity,
    coalesce(sum(r.lost_quantity), 0)::integer as lost_quantity,
    coalesce(sum(r.damaged_quantity), 0)::integer as damaged_quantity,
    coalesce(sum(r.unresolved_quantity), 0)::integer as unresolved_quantity
  from public.order_item_terminal_reconciliation r
  group by r.order_id
)
select
  o.id as order_id,
  o.order_number,
  o.lifecycle_state,
  coalesce(pr.parcel_count, 0)::integer as parcel_count,
  coalesce(pr.delivered_parcel_count, 0)::integer as delivered_parcel_count,
  coalesce(pr.rto_parcel_count, 0)::integer as rto_parcel_count,
  coalesce(pr.lost_parcel_count, 0)::integer as lost_parcel_count,
  coalesce(pr.damaged_parcel_count, 0)::integer as damaged_parcel_count,
  coalesce(pr.nonterminal_parcel_count, 0)::integer as nonterminal_parcel_count,
  coalesce(ir.ordered_quantity, 0)::integer as ordered_quantity,
  coalesce(ir.delivered_quantity, 0)::integer as delivered_quantity,
  coalesce(ir.rto_quantity, 0)::integer as rto_quantity,
  coalesce(ir.lost_quantity, 0)::integer as lost_quantity,
  coalesce(ir.damaged_quantity, 0)::integer as damaged_quantity,
  coalesce(ir.unresolved_quantity, 0)::integer as unresolved_quantity,
  (
    coalesce(pr.lost_parcel_count, 0) + coalesce(pr.damaged_parcel_count, 0) > 0
  ) as has_lost_or_damaged_exception,
  case
    when coalesce(pr.nonterminal_parcel_count, 0) > 0 then 'In Progress'
    when coalesce(pr.parcel_count, 0) > 0
      and coalesce(pr.delivered_parcel_count, 0) = pr.parcel_count then 'Delivered'
    when coalesce(pr.parcel_count, 0) > 0
      and coalesce(pr.rto_parcel_count, 0) = pr.parcel_count then 'RTO'
    when coalesce(pr.parcel_count, 0) > 0
      and coalesce(pr.lost_parcel_count, 0) + coalesce(pr.damaged_parcel_count, 0) = pr.parcel_count then 'Exception'
    when coalesce(pr.parcel_count, 0) > 0 then 'Partial'
    else 'Pending Fulfillment'
  end as fulfillment_summary
from public.orders o
left join parcel_rollup pr on pr.order_id = o.id
left join item_rollup ir on ir.order_id = o.id;

comment on view public.order_fulfillment_summary is
  'P10-T163: read-only order fulfillment projection derived from authoritative parcel states and terminal item quantities; mixed outcomes are Partial and Lost/Damaged exceptions remain explicit.';

revoke all on public.order_fulfillment_summary from anon;
grant select on public.order_fulfillment_summary to authenticated;
