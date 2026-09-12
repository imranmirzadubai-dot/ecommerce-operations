begin;

-- Browser roles have no direct table mutation privileges.
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;
grant select on public.profiles, public.customers, public.shippers, public.orders, public.order_items,
  public.parcels, public.parcel_items, public.delivery_outcomes, public.cod_obligations,
  public.cod_obligation_allocations, public.cod_receipts, public.financial_adjustments,
  public.invoice_records, public.order_events, public.audit_logs, public.import_batches, public.import_rows
  to authenticated;

-- Identifier sequences are never directly exposed to browser roles.
revoke all on all sequences in schema public from anon;
revoke all on all sequences in schema public from authenticated;

-- Only the approved application command surface is executable by authenticated users.
revoke all on all functions in schema public from anon;
revoke all on all functions in schema public from authenticated;
grant execute on function public.app_role() to authenticated;
grant execute on function public.create_order(text,text,text,text,numeric,jsonb,text,text) to authenticated;
grant execute on function public.confirm_order(uuid,text) to authenticated;
grant execute on function public.cancel_order(uuid,text) to authenticated;
grant execute on function public.cancel_parcel(uuid,text) to authenticated;

commit;
