-- E-Commerce Operations MVP P8-T128
-- Invoice template/version lineage.
-- Source: locked Master Implementation Plan v4.0, Invoice and Printing Contract.
--
-- A template version is a first-class immutable record. Invoice records retain
-- the exact version identifier used at generation time so later template
-- changes do not rewrite historical invoice lineage.

create table if not exists public.invoice_template_versions (
  version text primary key,
  template_key text not null,
  renderer_revision text not null,
  supersedes_version text references public.invoice_template_versions(version) on delete restrict,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete restrict,
  check (btrim(version) <> ''),
  check (btrim(template_key) <> ''),
  check (btrim(renderer_revision) <> '')
);

create index if not exists idx_invoice_template_versions_supersedes
  on public.invoice_template_versions(supersedes_version);

-- Register the locked MVP baseline independently of user creation. Later
-- controlled versions can record the creating Admin through created_by.
insert into public.invoice_template_versions (
  version,
  template_key,
  renderer_revision,
  supersedes_version,
  created_by
)
values ('v1.0', 'standard-a4', 'invoice-renderer-p8', null, null)
on conflict (version) do nothing;

-- Existing invoice records already carry template_version. Make that field
-- referentially anchored to the controlled lineage table. Existing databases
-- with invoice records must first register their historical versions; the
-- migration fails rather than silently relabeling or rewriting history.
alter table public.invoice_records
  drop constraint if exists invoice_records_template_version_fkey;

alter table public.invoice_records
  add constraint invoice_records_template_version_fkey
  foreign key (template_version)
  references public.invoice_template_versions(version)
  on delete restrict;

alter table public.invoice_template_versions enable row level security;

create policy invoice_template_versions_authenticated_select
  on public.invoice_template_versions
  for select to authenticated
  using (public.app_role() in ('sales','operations','admin'));

revoke all on public.invoice_template_versions from anon, authenticated;
grant select on public.invoice_template_versions to authenticated;

-- Template versions are immutable lineage records. No browser role receives
-- direct INSERT/UPDATE/DELETE privileges; future creation belongs in a
-- privileged, audited configuration command.
create or replace function public.prevent_invoice_template_version_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Invoice template versions are immutable';
end;
$$;

revoke all on function public.prevent_invoice_template_version_mutation() from public;

drop trigger if exists trg_invoice_template_versions_immutable
  on public.invoice_template_versions;

create trigger trg_invoice_template_versions_immutable
before update or delete on public.invoice_template_versions
for each row execute function public.prevent_invoice_template_version_mutation();
