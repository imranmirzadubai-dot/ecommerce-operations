begin;

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

alter table public.parcels enable row level security;
revoke all on public.parcels from anon;
revoke all on public.parcels from authenticated;
grant select on public.parcels to authenticated;

create index if not exists idx_parcels_order_id on public.parcels(order_id);
create index if not exists idx_parcels_state on public.parcels(state);
create index if not exists idx_parcels_shipper_id on public.parcels(shipper_id);
create index if not exists idx_parcels_tracking_id on public.parcels(tracking_id);

commit;
