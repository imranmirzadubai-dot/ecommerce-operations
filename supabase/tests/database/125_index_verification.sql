begin;

select plan(24);
set local role postgres;

-- P14-T214: verify the authoritative index contract in the local/CI database.
-- This is repository/runtime verification, not a production physical-index audit.

select ok((select count(*) from pg_indexes where schemaname='public' and tablename='customers' and indexname='idx_customers_normalized_phone') = 1,'customers normalized_phone index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='orders' and indexname='idx_orders_customer_id') = 1,'orders customer_id index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='orders' and indexname='idx_orders_order_date') = 1,'orders order_date index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='orders' and indexname='idx_orders_lifecycle_state') = 1,'orders lifecycle_state index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='order_items' and indexname='idx_order_items_order_id') = 1,'order_items order_id index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='parcels' and indexname='idx_parcels_order_id') = 1,'parcels order_id index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='parcels' and indexname='idx_parcels_state') = 1,'parcels state index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='parcels' and indexname='idx_parcels_shipper_id') = 1,'parcels shipper_id index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='parcels' and indexname='idx_parcels_tracking_id') = 1,'parcels tracking_id index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='parcel_items' and indexname='idx_parcel_items_order_item_id') = 1,'parcel_items order_item_id index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='delivery_outcomes' and indexname='idx_delivery_outcomes_parcel_id') = 1,'delivery_outcomes parcel_id index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='order_events' and indexname='idx_order_events_order_id') = 1,'order_events order_id index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='order_events' and indexname='idx_order_events_parcel_id') = 1,'order_events parcel_id index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='financial_adjustments' and indexname='idx_financial_adjustments_order_id') = 1,'financial_adjustments order_id index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='audit_logs' and indexname='idx_audit_logs_entity') = 1,'audit_logs entity index exists');
select ok((select count(*) from pg_indexes where schemaname='public' and tablename='import_rows' and indexname='idx_import_rows_batch_id') = 1,'import_rows batch_id index exists');

select ok((select indexdef from pg_indexes where schemaname='public' and indexname='idx_customers_normalized_phone') like '%(normalized_phone)%','customers index covers normalized_phone');
select ok((select indexdef from pg_indexes where schemaname='public' and indexname='idx_orders_customer_id') like '%(customer_id)%','orders customer index covers customer_id');
select ok((select indexdef from pg_indexes where schemaname='public' and indexname='idx_orders_order_date') like '%(order_date)%','orders date index covers order_date');
select ok((select indexdef from pg_indexes where schemaname='public' and indexname='idx_orders_lifecycle_state') like '%(lifecycle_state)%','orders lifecycle index covers lifecycle_state');
select ok((select indexdef from pg_indexes where schemaname='public' and indexname='idx_parcels_order_id') like '%(order_id)%','parcels order index covers order_id');
select ok((select indexdef from pg_indexes where schemaname='public' and indexname='idx_parcels_state') like '%(state)%','parcels state index covers state');
select ok((select indexdef from pg_indexes where schemaname='public' and indexname='idx_parcels_tracking_id') like '%(tracking_id)%','parcels tracking index covers tracking_id');
select ok((select indexdef from pg_indexes where schemaname='public' and indexname='idx_delivery_outcomes_parcel_id') like '%(parcel_id)%','delivery outcomes index covers parcel_id');

select * from finish();
rollback;
