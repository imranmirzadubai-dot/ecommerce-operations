begin;

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

alter table public.order_items enable row level security;
revoke all on public.order_items from anon;
revoke all on public.order_items from authenticated;
grant select on public.order_items to authenticated;

create index if not exists idx_order_items_order_id on public.order_items(order_id);

commit;
