begin;

select plan(24);

select has_view('public', 'report_kpi_orders', 'orders KPI view exists');
select has_view('public', 'report_kpi_parcels', 'parcels KPI view exists');
select has_view('public', 'report_kpi_delivery_outcomes', 'delivery outcomes KPI view exists');
select has_view('public', 'report_kpi_financial', 'financial KPI view exists');
select has_view('public', 'report_kpi_imports', 'historical import KPI view exists');

select has_column('public', 'report_kpi_orders', 'lifecycle_state', 'orders KPI exposes lifecycle state');
select has_column('public', 'report_kpi_orders', 'order_count', 'orders KPI exposes order count');
select has_column('public', 'report_kpi_orders', 'original_amount_total', 'orders KPI exposes immutable original amount total');

select has_column('public', 'report_kpi_parcels', 'parcel_state', 'parcels KPI exposes physical state');
select has_column('public', 'report_kpi_parcels', 'parcel_count', 'parcels KPI exposes parcel count');

select has_column('public', 'report_kpi_delivery_outcomes', 'outcome', 'delivery KPI exposes outcome');
select has_column('public', 'report_kpi_delivery_outcomes', 'outcome_count', 'delivery KPI exposes outcome count');

select has_column('public', 'report_kpi_financial', 'cod_obligation_total', 'financial KPI exposes COD obligation total');
select has_column('public', 'report_kpi_financial', 'cod_receipt_total', 'financial KPI exposes COD receipt total');
select has_column('public', 'report_kpi_financial', 'cod_variance_total', 'financial KPI exposes COD variance total');
select has_column('public', 'report_kpi_financial', 'financial_adjustment_total', 'financial KPI exposes adjustment total');

select has_column('public', 'report_kpi_imports', 'source_row_total', 'import KPI exposes source row total');
select has_column('public', 'report_kpi_imports', 'matched_row_total', 'import KPI exposes matched rows');
select has_column('public', 'report_kpi_imports', 'create_row_total', 'import KPI exposes create rows');
select has_column('public', 'report_kpi_imports', 'exception_row_total', 'import KPI exposes exception rows');
select has_column('public', 'report_kpi_imports', 'reconciled_batch_count', 'import KPI exposes reconciled batch count');

select ok(
  has_table_privilege('authenticated', 'public.report_kpi_orders', 'SELECT'),
  'authenticated users can read orders KPI view'
);
select ok(
  not has_table_privilege('anon', 'public.report_kpi_orders', 'SELECT'),
  'anonymous users cannot read orders KPI view'
);
select ok(
  has_table_privilege('authenticated', 'public.report_kpi_financial', 'SELECT'),
  'authenticated users can read financial KPI view'
);
select ok(
  not has_table_privilege('anon', 'public.report_kpi_financial', 'SELECT'),
  'anonymous users cannot read financial KPI view'
);

select finish();
rollback;
