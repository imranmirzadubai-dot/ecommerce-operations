-- P17-T295: extend the existing shippers foundation for courier management.
-- Additive only: preserve public.shippers as the courier master and keep
-- parcels.shipper_id as the parcel-level relationship.

begin;

create sequence if not exists public.shipper_code_seq;

alter table public.shippers
  add column if not exists courier_code text,
  add column if not exists contact_name text,
  add column if not exists contact_phone text,
  add column if not exists contact_email text,
  add column if not exists address text,
  add column if not exists notes text;

update public.shippers
set courier_code = 'CRR-' || lpad(nextval('public.shipper_code_seq')::text, 6, '0')
where courier_code is null;

alter table public.shippers
  alter column courier_code set not null;

alter table public.shippers
  add constraint shippers_courier_code_format_chk
  check (courier_code ~ '^CRR-[0-9]{6,}$');

create unique index if not exists uq_shippers_courier_code
  on public.shippers(courier_code);

create index if not exists idx_shippers_active
  on public.shippers(active);

revoke all on public.shippers from anon;
revoke all on public.shippers from authenticated;
grant select on public.shippers to authenticated;

commit;
