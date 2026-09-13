-- P3-T054: Implement shippers table and role-safe read boundary
-- Reconciles the existing foundation table with the locked Phase 2 contract.

begin;

create table if not exists public.shippers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.shippers enable row level security;

revoke all on public.shippers from anon;
revoke all on public.shippers from authenticated;
grant select on public.shippers to authenticated;

commit;
