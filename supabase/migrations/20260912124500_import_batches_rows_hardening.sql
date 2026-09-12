begin;

alter table public.import_rows
  drop constraint if exists import_rows_status_check;
alter table public.import_rows
  add constraint import_rows_status_check
  check (status in ('Pending','Valid','Invalid','Imported','Skipped','Failed'));

create index if not exists idx_import_batches_status on public.import_batches(status);
create index if not exists idx_import_batches_initiated_by on public.import_batches(initiated_by);
create index if not exists idx_import_rows_status on public.import_rows(status);

alter table public.import_batches enable row level security;
alter table public.import_rows enable row level security;
revoke all on public.import_batches from anon;
revoke all on public.import_batches from authenticated;
revoke all on public.import_rows from anon;
revoke all on public.import_rows from authenticated;
grant select on public.import_batches to authenticated;
grant select on public.import_rows to authenticated;

drop policy if exists import_batches_admin_select on public.import_batches;
create policy import_batches_admin_select on public.import_batches
  for select to authenticated
  using (public.app_role() = 'admin');

drop policy if exists import_rows_admin_select on public.import_rows;
create policy import_rows_admin_select on public.import_rows
  for select to authenticated
  using (public.app_role() = 'admin');

commit;
