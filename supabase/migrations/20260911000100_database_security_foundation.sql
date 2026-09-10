-- E-Commerce Operations MVP
-- Phase 3: Database & Security Foundation
-- Source: Master Implementation Plan v4.0, sections 10-20.

create extension if not exists pgcrypto;

create type public.app_role as enum ('sales', 'operations', 'admin');
create type public.order_lifecycle_state as enum ('draft', 'confirmed', 'active', 'completed', 'cancelled');
create type public.parcel_state as enum ('prepared', 'dispatched', 'in_transit', 'ndr', 'delivered', 'rto', 'lost', 'damaged', 'cancelled');
create type public.allocation_state as enum ('allocated', 'released', 'reversed');
create type public.cod_state as enum ('open', 'closed', 'voided', 'exception');
create type public.cod_receipt_state as enum ('received', 'exception');
create type public.import_status as enum ('pending', 'validated', 'committed', 'failed');
create type public.import_row_status as enum ('pending', 'valid', 'error', 'committed');

create sequence public.customer_code_seq;
create sequence public.order_number_seq;
create sequence public.parcel_number_seq;
create sequence public.invoice_number_seq;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  name text not null,
  email text not null,
  role public.app_role not null default 'sales',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  customer_code text not null unique default ('CUS-' || lpad(nextval('public.customer_code_seq')::text, 6, '0')),
  name text not null,
  phone text,
  normalized_phone text,
  address text,
  city text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index customers_normalized_phone_uidx on public.customers(normalized_phone) where normalized_phone is not null;
create index customers_name_idx on public.customers(lower(name));

create table public.shippers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default ('ORD-' || lpad(nextval('public.order_number_seq')::text, 6, '0')),
  customer_id uuid not null references public.customers(id) on delete restrict,
  order_date date not null default (timezone('Asia/Dubai', now())::date),
  currency_code text not null default 'AED' check (currency_code = 'AED'),
  original_amount numeric(12,2) not null check (original_amount >= 0),
  lifecycle_state public.order_lifecycle_state not null default 'draft',
  fulfillment_summary text not null default 'In Progress',
  notes text,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index orders_customer_id_idx on public.orders(customer_id);
create index orders_order_date_idx on public.orders(order_date);
create index orders_lifecycle_state_idx on public.orders(lifecycle_state);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  line_no integer not null check (line_no > 0),
  description text not null,
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(order_id, line_no)
);
create index order_items_order_id_idx on public.order_items(order_id);

create table public.parcels (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  parcel_number text not null unique default ('PCL-' || lpad(nextval('public.parcel_number_seq')::text, 6, '0')),
  barcode text not null unique,
  shipper_id uuid references public.shippers(id) on delete restrict,
  tracking_id text unique,
  state public.parcel_state not null default 'prepared',
  dispatch_at timestamptz,
  rto_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (barcode = parcel_number)
);
create index parcels_order_id_idx on public.parcels(order_id);
create index parcels_state_idx on public.parcels(state);
create index parcels_shipper_id_idx on public.parcels(shipper_id);
create index parcels_tracking_id_idx on public.parcels(tracking_id);

create table public.parcel_items (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references public.parcels(id) on delete restrict,
  order_item_id uuid not null references public.order_items(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  allocation_state public.allocation_state not null default 'allocated',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index parcel_items_parcel_id_idx on public.parcel_items(parcel_id);
create index parcel_items_order_item_id_idx on public.parcel_items(order_item_id);
create unique index parcel_items_active_pair_uidx on public.parcel_items(parcel_id, order_item_id) where allocation_state = 'allocated';

create table public.delivery_outcomes (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references public.parcels(id) on delete restrict,
  outcome text not null check (outcome in ('ndr','delivered','rto','lost','damaged')),
  note text,
  occurred_at timestamptz not null default now(),
  performed_by uuid not null references public.profiles(id) on delete restrict
);
create index delivery_outcomes_parcel_id_idx on public.delivery_outcomes(parcel_id);
create index delivery_outcomes_occurred_at_idx on public.delivery_outcomes(occurred_at);

create table public.cod_obligations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete restrict,
  expected_amount numeric(12,2) not null check (expected_amount >= 0),
  state public.cod_state not null default 'open',
  created_at timestamptz not null default now(),
  closed_at timestamptz,
  closed_by uuid references public.profiles(id) on delete restrict
);

create table public.cod_receipts (
  id uuid primary key default gen_random_uuid(),
  cod_obligation_id uuid not null references public.cod_obligations(id) on delete restrict,
  parcel_id uuid not null unique references public.parcels(id) on delete restrict,
  expected_amount_snapshot numeric(12,2) not null check (expected_amount_snapshot >= 0),
  received_amount numeric(12,2) not null check (received_amount >= 0),
  state public.cod_receipt_state not null,
  received_at timestamptz not null default now(),
  received_by uuid not null references public.profiles(id) on delete restrict
);
create index cod_receipts_obligation_idx on public.cod_receipts(cod_obligation_id);

create table public.financial_adjustments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  adjustment_type text not null,
  delta_amount numeric(12,2) not null,
  reason text not null,
  performed_by uuid not null references public.profiles(id) on delete restrict,
  performed_at timestamptz not null default now(),
  parcel_id uuid references public.parcels(id) on delete restrict,
  cod_receipt_id uuid references public.cod_receipts(id) on delete restrict
);
create index financial_adjustments_order_id_idx on public.financial_adjustments(order_id);

create table public.invoice_records (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  invoice_number text not null unique default ('INV-' || lpad(nextval('public.invoice_number_seq')::text, 6, '0')),
  template_version text not null,
  generated_at timestamptz not null default now(),
  generated_by uuid not null references public.profiles(id) on delete restrict,
  print_count integer not null default 0 check (print_count >= 0)
);
create index invoice_records_order_id_idx on public.invoice_records(order_id);

create table public.order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  parcel_id uuid references public.parcels(id) on delete restrict,
  event_type text not null,
  event_time timestamptz not null default now(),
  performed_by uuid references public.profiles(id) on delete restrict,
  notes text,
  metadata jsonb not null default '{}'::jsonb
);
create index order_events_order_id_idx on public.order_events(order_id);
create index order_events_parcel_id_idx on public.order_events(parcel_id);
create index order_events_event_time_idx on public.order_events(event_time);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor uuid references public.profiles(id) on delete restrict,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  request_id text,
  occurred_at timestamptz not null default now()
);
create index audit_logs_actor_idx on public.audit_logs(actor);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id);
create index audit_logs_occurred_at_idx on public.audit_logs(occurred_at);

create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  source_system text not null,
  source_file text not null,
  initiated_by uuid not null references public.profiles(id) on delete restrict,
  status public.import_status not null default 'pending',
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  reconciliation_summary jsonb not null default '{}'::jsonb
);

create table public.import_rows (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.import_batches(id) on delete restrict,
  source_row_number integer not null check (source_row_number > 0),
  source_record_id text,
  raw_data jsonb not null,
  normalized_data jsonb,
  status public.import_row_status not null default 'pending',
  error text,
  unique(batch_id, source_row_number)
);
create index import_rows_batch_id_idx on public.import_rows(batch_id);
create index import_rows_source_identity_idx on public.import_rows(batch_id, source_record_id);

-- Cross-entity allocation integrity: a parcel item must belong to the same order as its parcel/order item.
create or replace function public.validate_parcel_item_relationships()
returns trigger
language plpgsql
as $$
declare
  parcel_order uuid;
  item_order uuid;
begin
  select order_id into parcel_order from public.parcels where id = new.parcel_id;
  select order_id into item_order from public.order_items where id = new.order_item_id;
  if parcel_order is null or item_order is null or parcel_order <> item_order then
    raise exception 'parcel_item must reference an order item belonging to the parcel order';
  end if;
  return new;
end;
$$;
create trigger trg_validate_parcel_item_relationships
before insert or update on public.parcel_items
for each row execute function public.validate_parcel_item_relationships();

-- Active allocation cannot exceed the ordered quantity. This is deliberately enforced in PostgreSQL.
create or replace function public.validate_order_item_allocation()
returns trigger
language plpgsql
as $$
declare
  ordered_qty integer;
  allocated_qty integer;
begin
  select quantity into ordered_qty from public.order_items where id = new.order_item_id for update;
  if ordered_qty is null then
    raise exception 'order item does not exist';
  end if;
  select coalesce(sum(quantity), 0) into allocated_qty
  from public.parcel_items
  where order_item_id = new.order_item_id
    and allocation_state = 'allocated'
    and id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid);
  if new.allocation_state = 'allocated' and allocated_qty + new.quantity > ordered_qty then
    raise exception 'active parcel allocation exceeds ordered quantity';
  end if;
  return new;
end;
$$;
create trigger trg_validate_order_item_allocation
before insert or update on public.parcel_items
for each row execute function public.validate_order_item_allocation();

-- Barcode is generated from the same server-side parcel identifier.
create or replace function public.set_parcel_barcode()
returns trigger
language plpgsql
as $$
begin
  if new.barcode is null or new.barcode = '' then
    new.barcode := new.parcel_number;
  end if;
  if new.barcode <> new.parcel_number then
    raise exception 'barcode must equal parcel_number';
  end if;
  return new;
end;
$$;
create trigger trg_set_parcel_barcode
before insert or update on public.parcels
for each row execute function public.set_parcel_barcode();

create trigger trg_profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger trg_customers_updated_at before update on public.customers for each row execute function public.set_updated_at();
create trigger trg_shippers_updated_at before update on public.shippers for each row execute function public.set_updated_at();
create trigger trg_orders_updated_at before update on public.orders for each row execute function public.set_updated_at();
create trigger trg_order_items_updated_at before update on public.order_items for each row execute function public.set_updated_at();
create trigger trg_parcels_updated_at before update on public.parcels for each row execute function public.set_updated_at();
create trigger trg_parcel_items_updated_at before update on public.parcel_items for each row execute function public.set_updated_at();

-- Protected role lookup. SECURITY DEFINER avoids recursive RLS evaluation on profiles.
create or replace function public.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid() and active = true;
$$;
revoke all on function public.current_app_role() from public;
grant execute on function public.current_app_role() to authenticated;

-- RLS is enabled on all application tables. Direct client writes are intentionally blocked;
-- privileged/race-sensitive writes will use reviewed transactional commands.
alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.shippers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.parcels enable row level security;
alter table public.parcel_items enable row level security;
alter table public.delivery_outcomes enable row level security;
alter table public.cod_obligations enable row level security;
alter table public.cod_receipts enable row level security;
alter table public.financial_adjustments enable row level security;
alter table public.invoice_records enable row level security;
alter table public.order_events enable row level security;
alter table public.audit_logs enable row level security;
alter table public.import_batches enable row level security;
alter table public.import_rows enable row level security;

-- Authenticated users may read operational records. Sensitive audit/import data is restricted to Admin.
create policy profiles_self_or_admin_select on public.profiles for select to authenticated
using (id = auth.uid() or public.current_app_role() = 'admin');
create policy operational_select on public.customers for select to authenticated using (true);
create policy operational_select on public.shippers for select to authenticated using (true);
create policy operational_select on public.orders for select to authenticated using (true);
create policy operational_select on public.order_items for select to authenticated using (true);
create policy operational_select on public.parcels for select to authenticated using (true);
create policy operational_select on public.parcel_items for select to authenticated using (true);
create policy operational_select on public.delivery_outcomes for select to authenticated using (true);
create policy operational_select on public.cod_obligations for select to authenticated using (true);
create policy operational_select on public.cod_receipts for select to authenticated using (true);
create policy operational_select on public.financial_adjustments for select to authenticated using (public.current_app_role() = 'admin');
create policy operational_select on public.invoice_records for select to authenticated using (true);
create policy operational_select on public.order_events for select to authenticated using (true);
create policy audit_admin_select on public.audit_logs for select to authenticated using (public.current_app_role() = 'admin');
create policy import_admin_select on public.import_batches for select to authenticated using (public.current_app_role() = 'admin');
create policy import_admin_select on public.import_rows for select to authenticated using (public.current_app_role() = 'admin');

-- No direct INSERT/UPDATE/DELETE policies are created for authenticated users.
-- PostgreSQL therefore denies direct writes; server-side commands will be granted deliberately per command.

-- Explicit grants complement RLS. Authenticated clients receive read access only to approved operational tables.
grant usage on schema public to authenticated;
grant select on public.profiles, public.customers, public.shippers, public.orders, public.order_items,
  public.parcels, public.parcel_items, public.delivery_outcomes, public.cod_obligations, public.cod_receipts,
  public.invoice_records, public.order_events to authenticated;
grant select on public.financial_adjustments, public.audit_logs, public.import_batches, public.import_rows to authenticated;

-- Anonymous clients receive no application-table access.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

comment on table public.orders is 'Commercial transaction. original_amount is immutable after confirmation.';
comment on table public.parcels is 'Authoritative current physical lifecycle state.';
comment on table public.delivery_outcomes is 'Immutable delivery/NDR/outcome history.';
comment on table public.financial_adjustments is 'Append-only financial delta ledger; original order amount is never overwritten.';
comment on table public.audit_logs is 'Immutable security/change accountability log.';
