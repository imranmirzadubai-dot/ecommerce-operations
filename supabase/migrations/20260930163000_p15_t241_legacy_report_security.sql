begin;

revoke all on table
  public.order_delivery_rto_summary,
  public.order_fulfillment_summary,
  public.order_item_rto_reconciliation,
  public.order_item_terminal_reconciliation
from authenticated;

grant select on table
  public.order_delivery_rto_summary,
  public.order_fulfillment_summary,
  public.order_item_rto_reconciliation,
  public.order_item_terminal_reconciliation
to authenticated;

alter view public.order_delivery_rto_summary set (security_invoker = true);
alter view public.order_fulfillment_summary set (security_invoker = true);
alter view public.order_item_rto_reconciliation set (security_invoker = true);
alter view public.order_item_terminal_reconciliation set (security_invoker = true);

commit;