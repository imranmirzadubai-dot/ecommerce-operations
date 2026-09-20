# P14-T214 — Index Verification

## Scope

Verify that the locked database foundation contains the authoritative indexes required by the Orders, parcel, delivery, financial, audit, and import workloads.

## Evidence

`supabase/tests/database/125_index_verification.sql` is a rollback-scoped pgTAP contract test. It checks the expected index names in `pg_indexes` and verifies that each named index covers its intended column(s).

Verified index contract:

- `idx_customers_normalized_phone`
- `idx_orders_customer_id`
- `idx_orders_order_date`
- `idx_orders_lifecycle_state`
- `idx_order_items_order_id`
- `idx_parcels_order_id`
- `idx_parcels_state`
- `idx_parcels_shipper_id`
- `idx_parcels_tracking_id`
- `idx_parcel_items_order_item_id`
- `idx_delivery_outcomes_parcel_id`
- `idx_order_events_order_id`
- `idx_order_events_parcel_id`
- `idx_financial_adjustments_order_id`
- `idx_audit_logs_entity`
- `idx_import_rows_batch_id`

## Boundary

This milestone verifies the repository/database index contract in the local/CI runtime. It does not claim that the same physical indexes have been independently inspected in the production Supabase control plane.

No production business data is created or changed by the test; the transaction is rolled back.
