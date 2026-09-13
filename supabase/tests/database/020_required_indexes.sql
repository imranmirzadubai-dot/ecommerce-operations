begin;

select plan(13);

select has_index('public', 'idx_orders_created_by', 'orders created_by index exists');
select has_index('public', 'idx_parcel_items_parcel_id', 'parcel_items parcel_id index exists');
select has_index('public', 'idx_delivery_outcomes_occurred_at', 'delivery outcomes occurred_at index exists');
select has_index('public', 'idx_cod_obligation_allocations_obligation_id', 'COD allocation obligation index exists');
select has_index('public', 'idx_cod_obligation_allocations_parcel_id', 'COD allocation parcel index exists');
select has_index('public', 'idx_cod_receipts_cod_obligation_id', 'COD receipt obligation index exists');
select has_index('public', 'idx_financial_adjustments_parcel_id', 'financial adjustment parcel index exists');
select has_index('public', 'idx_financial_adjustments_cod_receipt_id', 'financial adjustment receipt index exists');
select has_index('public', 'idx_invoice_records_order_id', 'invoice order index exists');
select has_index('public', 'idx_order_events_event_time', 'order event time index exists');
select has_index('public', 'idx_audit_logs_occurred_at', 'audit log time index exists');
select has_index('public', 'idx_import_batches_status', 'import batch status index remains present');
select has_index('public', 'idx_import_rows_status', 'import row status index remains present');

select * from finish();
rollback;
