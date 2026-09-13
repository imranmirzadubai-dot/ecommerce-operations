-- E-Commerce Operations MVP P8-T129
-- Invoice print event tracking.
-- Source: locked Master Implementation Plan v4.0, Invoice and Printing Contract.
--
-- Every successful print command records an immutable domain event and atomically
-- increments invoice_records.print_count. The event snapshots the invoice's
-- template version so later template changes cannot rewrite print history.

create table if not exists public.invoice_print_events (
  id uuid primary key default gen_random_uuid(),
  invoice_record_id uuid not null references public.invoice_records(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  template_version text not null references public.invoice_template_versions(version) on delete restrict,
  print_mode text not null check (print_mode in ('individual','batch')),
  printed_at timestamptz not null default now(),
  printed_by uuid not null references auth.users(id) on delete restrict,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists idx_invoice_print_events_invoice_record_id
  on public.invoice_print_events(invoice_record_id);
create index if not exists idx_invoice_print_events_order_id
  on public.invoice_print_events(order_id);
create index if not exists idx_invoice_print_events_printed_at
  on public.invoice_print_events(printed_at);
create index if not exists idx_invoice_print_events_printed_by
  on public.invoice_print_events(printed_by);

alter table public.invoice_print_events enable row level security;

create policy invoice_print_events_authenticated_select
  on public.invoice_print_events
  for select to authenticated
  using (public.app_role() in ('sales','operations','admin'));

revoke all on public.invoice_print_events from anon, authenticated;
grant select on public.invoice_print_events to authenticated;

create or replace function public.prevent_invoice_print_event_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Invoice print events are immutable';
end;
$$;

revoke all on function public.prevent_invoice_print_event_mutation() from public;

drop trigger if exists trg_invoice_print_events_immutable
  on public.invoice_print_events;

create trigger trg_invoice_print_events_immutable
before update or delete on public.invoice_print_events
for each row execute function public.prevent_invoice_print_event_mutation();

create or replace function public.record_invoice_print(
  p_invoice_record_id uuid,
  p_print_mode text,
  p_metadata jsonb default '{}'::jsonb
)
returns table (
  print_event_id uuid,
  invoice_record_id uuid,
  order_id uuid,
  template_version text,
  print_count integer
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_order_id uuid;
  v_template_version text;
  v_print_event_id uuid;
  v_print_count integer;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then
    raise exception using errcode='42501', message='Authenticated operational role required';
  end if;

  if p_invoice_record_id is null then
    raise exception using errcode='22023', message='Invoice record is required';
  end if;

  if p_print_mode not in ('individual','batch') then
    raise exception using errcode='22023', message='Print mode must be individual or batch';
  end if;

  if p_metadata is null or jsonb_typeof(p_metadata) <> 'object' then
    raise exception using errcode='22023', message='Print metadata must be a JSON object';
  end if;

  select ir.order_id, ir.template_version
    into v_order_id, v_template_version
  from public.invoice_records ir
  where ir.id = p_invoice_record_id
  for update;

  if not found then
    raise exception using errcode='P0002', message='Invoice record not found';
  end if;

  insert into public.invoice_print_events (
    invoice_record_id,
    order_id,
    template_version,
    print_mode,
    printed_by,
    metadata
  )
  values (
    p_invoice_record_id,
    v_order_id,
    v_template_version,
    p_print_mode,
    auth.uid(),
    p_metadata
  )
  returning id into v_print_event_id;

  update public.invoice_records
     set print_count = print_count + 1
   where id = p_invoice_record_id
   returning print_count into v_print_count;

  return query
  select v_print_event_id,
         p_invoice_record_id,
         v_order_id,
         v_template_version,
         v_print_count;
end;
$$;

revoke all on function public.record_invoice_print(uuid,text,jsonb) from public;
grant execute on function public.record_invoice_print(uuid,text,jsonb) to authenticated;
