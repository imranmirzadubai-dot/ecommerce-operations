-- E-Commerce Operations MVP v4.0
-- Database & Security Foundation
-- Source: locked Master Implementation Plan v4.0

create sequence if not exists public.customer_code_seq;
create sequence if not exists public.order_number_seq;
create sequence if not exists public.parcel_number_seq;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  name text not null,
  email text not null,
  role text not null check (role in ('sales','operations','admin')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  customer_code text not null unique default ('CUS-' || lpad(nextval('public.customer_code_seq')::text, 6, '0')),
  name text not null,
  phone text,
  normalized_phone text unique,
  address text,
  city text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shippers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default ('ORD-' || lpad(nextval('public.order_number_seq')::text, 6, '0')),
  customer_id uuid not null references public.customers(id) on delete restrict,
  order_date date not null default current_date,
  currency_code text not null default 'AED' check (currency_code = 'AED'),
  original_amount numeric(12,2) not null check (original_amount >= 0),
  lifecycle_state text not null default 'Draft' check (lifecycle_state in ('Draft','Confirmed','Active','Completed','Cancelled')),
  fulfillment_summary text,
  notes text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  line_no integer not null check (line_no > 0),
  description text not null,
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, line_no)
);

create table if not exists public.parcels (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  parcel_number text not null unique default ('PCL-' || lpad(nextval('public.parcel_number_seq')::text, 6, '0')),
  barcode text not null unique,
  shipper_id uuid references public.shippers(id) on delete restrict,
  tracking_id text unique,
  state text not null default 'Prepared' check (state in ('Prepared','Dispatched','In Transit','NDR','Delivered','RTO','Lost','Damaged','Cancelled')),
  dispatch_at timestamptz,
  rto_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (barcode = parcel_number)
);

create table if not exists public.parcel_items (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references public.parcels(id) on delete restrict,
  order_item_id uuid not null references public.order_items(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  allocation_state text not null default 'Allocated' check (allocation_state in ('Allocated','Released','Reversed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (parcel_id, order_item_id, allocation_state)
);

create table if not exists public.delivery_outcomes (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references public.parcels(id) on delete restrict,
  outcome text not null check (outcome in ('Delivered','RTO','Lost','Damaged','NDR')),
  note text,
  occurred_at timestamptz not null default now(),
  performed_by uuid not null references auth.users(id) on delete restrict
);

create table if not exists public.cod_obligations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete restrict,
  expected_amount numeric(12,2) not null check (expected_amount >= 0),
  state text not null default 'Outstanding' check (state in ('Outstanding','Partially Received','Received','Exception','Voided','Closed')),
  created_at timestamptz not null default now(),
  closed_at timestamptz,
  closed_by uuid references auth.users(id) on delete restrict
);

-- Explicit parcel-level COD allocation is required to reconcile an order obligation across parcels.
create table if not exists public.cod_obligation_allocations (
  id uuid primary key default gen_random_uuid(),
  cod_obligation_id uuid not null references public.cod_obligations(id) on delete restrict,
  parcel_id uuid not null references public.parcels(id) on delete restrict,
  expected_amount numeric(12,2) not null check (expected_amount >= 0),
  created_at timestamptz not null default now(),
  unique (cod_obligation_id, parcel_id)
);

create table if not exists public.cod_receipts (
  id uuid primary key default gen_random_uuid(),
  cod_obligation_id uuid not null references public.cod_obligations(id) on delete restrict,
  parcel_id uuid not null unique references public.parcels(id) on delete restrict,
  expected_amount_snapshot numeric(12,2) not null check (expected_amount_snapshot >= 0),
  received_amount numeric(12,2) not null check (received_amount >= 0),
  state text not null check (state in ('Received','Exception')),
  received_at timestamptz not null default now(),
  received_by uuid not null references auth.users(id) on delete restrict
);

create table if not exists public.financial_adjustments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  adjustment_type text not null,
  delta_amount numeric(12,2) not null,
  reason text not null,
  performed_by uuid not null references auth.users(id) on delete restrict,
  performed_at timestamptz not null default now(),
  parcel_id uuid references public.parcels(id) on delete restrict,
  cod_receipt_id uuid references public.cod_receipts(id) on delete restrict
);

create table if not exists public.invoice_records (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  invoice_number text not null unique,
  template_version text not null,
  generated_at timestamptz not null default now(),
  generated_by uuid not null references auth.users(id) on delete restrict,
  print_count integer not null default 0 check (print_count >= 0)
);

create table if not exists public.order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  parcel_id uuid references public.parcels(id) on delete restrict,
  event_type text not null,
  event_time timestamptz not null default now(),
  performed_by uuid not null references auth.users(id) on delete restrict,
  notes text,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor uuid references auth.users(id) on delete restrict,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  request_id text,
  occurred_at timestamptz not null default now()
);

create table if not exists public.import_batches (
  id uuid primary key default gen_random_uuid(),
  source_system text not null,
  source_file text not null,
  initiated_by uuid not null references auth.users(id) on delete restrict,
  status text not null default 'Uploaded' check (status in ('Uploaded','Mapping','Validating','Ready','Importing','Completed','Failed','Rolled Back')),
  started_at timestamptz,
  completed_at timestamptz,
  reconciliation_summary jsonb
);

create table if not exists public.import_rows (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.import_batches(id) on delete restrict,
  source_row_number integer not null check (source_row_number > 0),
  source_record_id text,
  raw_data jsonb not null,
  normalized_data jsonb,
  status text not null default 'Pending',
  error text,
  unique (batch_id, source_row_number)
);

create index if not exists idx_customers_normalized_phone on public.customers(normalized_phone);
create index if not exists idx_orders_customer_id on public.orders(customer_id);
create index if not exists idx_orders_order_date on public.orders(order_date);
create index if not exists idx_orders_lifecycle_state on public.orders(lifecycle_state);
create index if not exists idx_order_items_order_id on public.order_items(order_id);
create index if not exists idx_parcels_order_id on public.parcels(order_id);
create index if not exists idx_parcels_state on public.parcels(state);
create index if not exists idx_parcels_shipper_id on public.parcels(shipper_id);
create index if not exists idx_parcels_tracking_id on public.parcels(tracking_id);
create index if not exists idx_parcel_items_order_item_id on public.parcel_items(order_item_id);
create index if not exists idx_delivery_outcomes_parcel_id on public.delivery_outcomes(parcel_id);
create index if not exists idx_order_events_order_id on public.order_events(order_id);
create index if not exists idx_order_events_parcel_id on public.order_events(parcel_id);
create index if not exists idx_financial_adjustments_order_id on public.financial_adjustments(order_id);
create index if not exists idx_audit_logs_entity on public.audit_logs(entity_type, entity_id);
create index if not exists idx_import_rows_batch_id on public.import_rows(batch_id);

create or replace function public.app_role()
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid()
    and p.active = true
$$;

revoke all on function public.app_role() from public;
grant execute on function public.app_role() to authenticated;

-- RLS is enabled now. State-changing writes will be exposed through transactional commands,
-- not direct table updates from the browser.
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

-- Minimal read policies for authenticated operational users.
create policy profiles_self_select on public.profiles for select to authenticated using (id = auth.uid());
create policy customers_authenticated_select on public.customers for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy shippers_authenticated_select on public.shippers for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy orders_authenticated_select on public.orders for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy order_items_authenticated_select on public.order_items for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy parcels_authenticated_select on public.parcels for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy parcel_items_authenticated_select on public.parcel_items for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy delivery_outcomes_authenticated_select on public.delivery_outcomes for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy cod_obligations_authenticated_select on public.cod_obligations for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy cod_obligation_allocations_authenticated_select on public.cod_obligation_allocations for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy cod_receipts_authenticated_select on public.cod_receipts for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy financial_adjustments_authenticated_select on public.financial_adjustments for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy invoice_records_authenticated_select on public.invoice_records for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy order_events_authenticated_select on public.order_events for select to authenticated using (public.app_role() in ('sales','operations','admin'));
create policy audit_logs_admin_select on public.audit_logs for select to authenticated using (public.app_role() = 'admin');
create policy import_batches_admin_select on public.import_batches for select to authenticated using (public.app_role() = 'admin');
create policy import_rows_admin_select on public.import_rows for select to authenticated using (public.app_role() = 'admin');

-- Explicit grants: authenticated users receive SELECT only. No direct table writes are granted here.
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;
grant select on public.profiles, public.customers, public.shippers, public.orders, public.order_items,
  public.parcels, public.parcel_items, public.delivery_outcomes, public.cod_obligations,
  public.cod_obligation_allocations, public.cod_receipts, public.financial_adjustments,
  public.invoice_records, public.order_events, public.audit_logs, public.import_batches, public.import_rows
  to authenticated;
