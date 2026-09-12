begin;

select plan(7);

select has_table('public', 'import_batches', 'import_batches table exists');
select has_table('public', 'import_rows', 'import_rows table exists');
select has_index('public', 'idx_import_batches_status', 'batch status index exists');
select has_index('public', 'idx_import_rows_status', 'row status index exists');
select policies_are('public', 'import_batches', ARRAY['import_batches_admin_select'], 'import_batches has expected admin-only RLS policy');
select policies_are('public', 'import_rows', ARRAY['import_rows_admin_select'], 'import_rows has expected admin-only RLS policy');
select throws_ok(
  $$select public.app_role()$$,
  NULL,
  NULL,
  'app_role remains callable for policy evaluation'
);

select * from finish();
rollback;
