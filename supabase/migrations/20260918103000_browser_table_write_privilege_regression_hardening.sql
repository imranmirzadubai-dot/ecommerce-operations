-- Regression hardening: browser roles must never receive direct table writes.
-- Commands remain the authoritative mutation surface.
revoke insert, update, delete, truncate, references, trigger on all tables in schema public from anon;
revoke insert, update, delete, truncate, references, trigger on all tables in schema public from authenticated;

grant select on public.profiles, public.customers, public.shippers, public.orders, public.order_items,
  public.parcels, public.parcel_items, public.delivery_outcomes, public.cod_obligations,
  public.cod_obligation_allocations, public.cod_receipts, public.financial_adjustments,
  public.invoice_records, public.order_events, public.audit_logs, public.import_batches, public.import_rows
  to authenticated;
