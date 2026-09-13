begin;

create index if not exists idx_orders_created_by on public.orders(created_by);
create index if not exists idx_parcel_items_parcel_id on public.parcel_items(parcel_id);
create index if not exists idx_delivery_outcomes_occurred_at on public.delivery_outcomes(occurred_at);
create index if not exists idx_cod_obligation_allocations_obligation_id on public.cod_obligation_allocations(cod_obligation_id);
create index if not exists idx_cod_obligation_allocations_parcel_id on public.cod_obligation_allocations(parcel_id);
create index if not exists idx_cod_receipts_cod_obligation_id on public.cod_receipts(cod_obligation_id);
create index if not exists idx_financial_adjustments_parcel_id on public.financial_adjustments(parcel_id);
create index if not exists idx_financial_adjustments_cod_receipt_id on public.financial_adjustments(cod_receipt_id);
create index if not exists idx_invoice_records_order_id on public.invoice_records(order_id);
create index if not exists idx_order_events_event_time on public.order_events(event_time);
create index if not exists idx_audit_logs_occurred_at on public.audit_logs(occurred_at);

commit;
