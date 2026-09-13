begin;

select plan(6);

select has_table('public', 'import_batches', 'import_batches table exists');
select has_table('public', 'import_rows', 'import_rows table exists');
select has_index('public', 'idx_import_batches_status', 'batch status index exists');
select has_index('public', 'idx_import_rows_status', 'row status index exists');
select policies_are('public', 'import_batches', ARRAY['import_batches_admin_select'], 'import_batches has expected admin-only RLS policy');
select policies_are('public', 'import_rows', ARRAY['import_rows_admin_select'], 'import_rows has expected admin-only RLS policy');

select * from finish();
rollback;
