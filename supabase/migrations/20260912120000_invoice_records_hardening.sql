begin;

alter table public.invoice_records
  add constraint invoice_records_invoice_number_unique unique (invoice_number);

alter table public.invoice_records
  enable row level security;

revoke all on public.invoice_records from anon;
revoke all on public.invoice_records from authenticated;
grant select on public.invoice_records to authenticated;

commit;
