begin;

select plan(7);

select has_table('public', 'invoice_records', 'invoice_records exists');
select has_unique('public', 'invoice_records', 'invoice_records_invoice_number_key', 'invoice number unique');
select has_column('public', 'invoice_records', 'invoice_number', 'invoice number exists');
select has_column('public', 'invoice_records', 'order_id', 'order id exists');
select has_column('public', 'invoice_records', 'issued_at', 'issued timestamp exists');
select row_security_active('public.invoice_records');
select has_select_privilege('authenticated', 'public.invoice_records', 'SELECT granted to authenticated');

select * from finish();
rollback;
