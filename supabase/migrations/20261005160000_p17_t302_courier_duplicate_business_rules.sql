-- P17-T302: enforce normalized courier-name uniqueness.
-- Preserve public.shippers as the courier master and prevent duplicate
-- business identities caused by case or surrounding whitespace differences.

begin;

create unique index if not exists uq_shippers_courier_name_normalized
  on public.shippers (lower(btrim(name)));

commit;
