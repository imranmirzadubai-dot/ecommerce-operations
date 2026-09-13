begin;

-- P3-T055: reconcile the orders foundation with the locked financial contract.
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

alter table public.orders enable row level security;
revoke all on public.orders from anon;
revoke all on public.orders from authenticated;
grant select on public.orders to authenticated;

commit;
