begin;

-- P3-T071: translate the locked RLS matrix into the executable policy set.
-- Normal application roles have read-only direct table access; all state changes
-- remain command-mediated. Policies fail closed when app_role() is null.

alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.shippers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.parcels enable row level security;
alter table public.parcel_items enable row level security;
alter table public.delivery_outcomes enable row level security;
alter table public.cod_obligations enable row level security;
alter table public.cod_obligation_allocations enable row level security;
alter table public.cod_receipts enable row level security;
alter table public.financial_adjustments enable row level security;
alter table public.invoice_records enable row level security;
alter table public.order_events enable row level security;
alter table public.audit_logs enable row level security;
alter table public.import_batches enable row level security;
alter table public.import_rows enable row level security;

-- Replace the foundation SELECT policies with the exact Phase 2 policy names/predicates.
drop policy if exists profiles_self_select on public.profiles;
drop policy if exists customers_authenticated_select on public.customers;
drop policy if exists shippers_authenticated_select on public.shippers;
drop policy if exists orders_authenticated_select on public.orders;
drop policy if exists order_items_authenticated_select on public.order_items;
drop policy if exists parcels_authenticated_select on public.parcels;
drop policy if exists parcel_items_authenticated_select on public.parcel_items;
drop policy if exists delivery_outcomes_authenticated_select on public.delivery_outcomes;
drop policy if exists cod_obligations_authenticated_select on public.cod_obligations;
drop policy if exists cod_obligation_allocations_authenticated_select on public.cod_obligation_allocations;
drop policy if exists cod_receipts_authenticated_select on public.cod_receipts;
drop policy if exists financial_adjustments_authenticated_select on public.financial_adjustments;
drop policy if exists invoice_records_authenticated_select on public.invoice_records;
drop policy if exists order_events_authenticated_select on public.order_events;
drop policy if exists audit_logs_admin_select on public.audit_logs;
drop policy if exists import_batches_admin_select on public.import_batches;
drop policy if exists import_rows_admin_select on public.import_rows;

create policy profiles_self_select on public.profiles
  for select to authenticated using (id = auth.uid());

create policy customers_authenticated_select on public.customers
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy shippers_authenticated_select on public.shippers
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy orders_authenticated_select on public.orders
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy order_items_authenticated_select on public.order_items
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy parcels_authenticated_select on public.parcels
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy parcel_items_authenticated_select on public.parcel_items
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy delivery_outcomes_authenticated_select on public.delivery_outcomes
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy cod_obligations_authenticated_select on public.cod_obligations
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy cod_obligation_allocations_authenticated_select on public.cod_obligation_allocations
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy cod_receipts_authenticated_select on public.cod_receipts
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));

-- Financial adjustments are explicitly Admin-read-only under the locked matrix.
create policy financial_adjustments_admin_select on public.financial_adjustments
  for select to authenticated using (public.app_role() = 'admin');

create policy invoice_records_authenticated_select on public.invoice_records
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy order_events_authenticated_select on public.order_events
  for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy audit_logs_admin_select on public.audit_logs
  for select to authenticated using (public.app_role() = 'admin');
create policy import_batches_admin_select on public.import_batches
  for select to authenticated using (public.app_role() = 'admin');
create policy import_rows_admin_select on public.import_rows
  for select to authenticated using (public.app_role() = 'admin');

-- Explicitly remove any accidental direct browser write privileges. Commands are
-- the only application write boundary.
revoke insert, update, delete, truncate, references, trigger on all tables in schema public from anon, authenticated;
revoke all on all tables in schema public from anon;
grant select on public.profiles, public.customers, public.shippers, public.orders, public.order_items,
  public.parcels, public.parcel_items, public.delivery_outcomes, public.cod_obligations,
  public.cod_obligation_allocations, public.cod_receipts, public.financial_adjustments,
  public.invoice_records, public.order_events, public.audit_logs, public.import_batches, public.import_rows
  to authenticated;

commit;
