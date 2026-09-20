-- P13-T202: Reconciliation report view contract tests.

select plan(32);

select has_view('public', 'report_cod_financial_reconciliation', 'COD and financial reconciliation report exists');
select has_view('public', 'report_historical_import_reconciliation', 'historical import reconciliation report exists');
select has_view('public', 'report_reconciliation_exceptions', 'reconciliation exceptions report exists');

select has_column('public', 'report_cod_financial_reconciliation', 'order_number', 'COD report exposes order number');
select has_column('public', 'report_cod_financial_reconciliation', 'parcel_number', 'COD report exposes parcel number');
select has_column('public', 'report_cod_financial_reconciliation', 'cod_obligation_amount', 'COD report exposes obligation amount');
select has_column('public', 'report_cod_financial_reconciliation', 'receipt_amount', 'COD report exposes receipt amount');
select has_column('public', 'report_cod_financial_reconciliation', 'variance', 'COD report exposes variance');
select has_column('public', 'report_cod_financial_reconciliation', 'financial_adjustment_total', 'COD report exposes adjustment total');
select has_column('public', 'report_cod_financial_reconciliation', 'effective_amount', 'COD report exposes effective amount');
select has_column('public', 'report_cod_financial_reconciliation', 'reconciliation_status', 'COD report exposes reconciliation status');

select has_column('public', 'report_historical_import_reconciliation', 'batch_id', 'import report exposes batch id');
select has_column('public', 'report_historical_import_reconciliation', 'source_system', 'import report exposes source system');
select has_column('public', 'report_historical_import_reconciliation', 'source_file', 'import report exposes source file');
select has_column('public', 'report_historical_import_reconciliation', 'total_source_rows', 'import report exposes source row count');
select has_column('public', 'report_historical_import_reconciliation', 'valid_count', 'import report exposes valid count');
select has_column('public', 'report_historical_import_reconciliation', 'error_count', 'import report exposes error count');
select has_column('public', 'report_historical_import_reconciliation', 'create_count', 'import report exposes create count');
select has_column('public', 'report_historical_import_reconciliation', 'matched_count', 'import report exposes matched count');
select has_column('public', 'report_historical_import_reconciliation', 'reconciliation_result', 'import report exposes reconciliation result');

select has_column('public', 'report_reconciliation_exceptions', 'exception_category', 'exceptions report exposes category');
select has_column('public', 'report_reconciliation_exceptions', 'entity_type', 'exceptions report exposes entity type');
select has_column('public', 'report_reconciliation_exceptions', 'entity_identifier', 'exceptions report exposes entity identifier');
select has_column('public', 'report_reconciliation_exceptions', 'expected_value', 'exceptions report exposes expected value');
select has_column('public', 'report_reconciliation_exceptions', 'actual_value', 'exceptions report exposes actual value');
select has_column('public', 'report_reconciliation_exceptions', 'variance', 'exceptions report exposes variance');
select has_column('public', 'report_reconciliation_exceptions', 'resolution_state', 'exceptions report exposes resolution state');

select is((select has_table_privilege('anon', 'public.report_cod_financial_reconciliation', 'select')), false, 'anonymous cannot select COD report');
select is((select has_table_privilege('anon', 'public.report_historical_import_reconciliation', 'select')), false, 'anonymous cannot select import report');
select is((select has_table_privilege('anon', 'public.report_reconciliation_exceptions', 'select')), false, 'anonymous cannot select exceptions report');
select is((select has_table_privilege('authenticated', 'public.report_cod_financial_reconciliation', 'select')), true, 'authenticated can select COD report');
select is((select has_table_privilege('authenticated', 'public.report_historical_import_reconciliation', 'select')), true, 'authenticated can select import report');
select is((select has_table_privilege('authenticated', 'public.report_reconciliation_exceptions', 'select')), true, 'authenticated can select exceptions report');

select * from finish();
