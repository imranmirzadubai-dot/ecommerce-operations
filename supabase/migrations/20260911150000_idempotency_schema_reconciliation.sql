-- E-Commerce Operations MVP v4.0
-- Reconcile pre-existing command_idempotency tables with the canonical schema.
-- Safe for fresh databases and for staging databases created from earlier foundations.

alter table public.command_idempotency
  add column if not exists status text not null default 'Started';

alter table public.command_idempotency
  drop constraint if exists command_idempotency_status_check;

alter table public.command_idempotency
  add constraint command_idempotency_status_check
  check (status in ('Started','Completed'));

create index if not exists idx_command_idempotency_created_at
  on public.command_idempotency(created_at);

alter table public.command_idempotency enable row level security;
revoke all on table public.command_idempotency from anon, authenticated;
