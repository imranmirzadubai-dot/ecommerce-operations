begin;

-- T068 reconciliation: make critical identifier/data-shape constraints explicit.
alter table public.customers add constraint customers_customer_code_not_blank check (btrim(customer_code) <> '');
alter table public.orders add constraint orders_order_number_not_blank check (btrim(order_number) <> '');
alter table public.parcels
  add constraint parcels_parcel_number_not_blank check (btrim(parcel_number) <> ''),
  add constraint parcels_barcode_not_blank check (btrim(barcode) <> '');
alter table public.import_batches add constraint import_batches_source_file_not_blank check (btrim(source_file) <> '');
alter table public.import_rows add constraint import_rows_raw_data_object check (jsonb_typeof(raw_data) = 'object');
commit;
