-- E-Commerce Operations MVP v4.0
-- P3-T053 — Customers table and phone uniqueness
-- Reconciles the Phase 3 customer identity contract without changing the domain model.

create or replace function public.normalize_phone(p_phone text)
returns text
language sql
immutable
strict
as $$
  select case
    when btrim(p_phone) = '' then null
    when regexp_replace(btrim(p_phone), '[^0-9+]', '', 'g') like '00%'
      then '+' || substring(regexp_replace(btrim(p_phone), '[^0-9+]', '', 'g') from 3)
    else regexp_replace(btrim(p_phone), '[^0-9+]', '', 'g')
  end
$$;

create or replace function public.set_customer_normalized_phone()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.normalized_phone := public.normalize_phone(new.phone);
  return new;
end;
$$;

revoke all on function public.normalize_phone(text) from public;
grant execute on function public.normalize_phone(text) to authenticated;

revoke all on function public.set_customer_normalized_phone() from public;

drop trigger if exists trg_set_customer_normalized_phone on public.customers;
create trigger trg_set_customer_normalized_phone
before insert or update of phone on public.customers
for each row
execute function public.set_customer_normalized_phone();

-- Existing non-null values are reconciled to the same canonical representation.
update public.customers
set normalized_phone = public.normalize_phone(phone)
where normalized_phone is distinct from public.normalize_phone(phone);

create unique index if not exists uq_customers_normalized_phone
  on public.customers(normalized_phone)
  where normalized_phone is not null;

alter table public.customers enable row level security;

revoke all on public.customers from anon;
revoke insert, update, delete, truncate, references, trigger on public.customers from authenticated;
grant select on public.customers to authenticated;
