-- P9-T139: canonical tracking-ID validation for dispatch.
-- Tracking IDs are globally unique in the MVP. Validation is server-side and
-- reusable by dispatch commands; it does not mutate parcel state.

alter table public.parcels
  add column if not exists normalized_tracking_id text;

update public.parcels
set normalized_tracking_id = upper(btrim(tracking_id))
where tracking_id is not null
  and normalized_tracking_id is null;

create unique index if not exists idx_parcels_normalized_tracking_id_unique
  on public.parcels(normalized_tracking_id)
  where normalized_tracking_id is not null;

create index if not exists idx_parcels_tracking_id_lookup
  on public.parcels(tracking_id);

create or replace function public.normalize_tracking_id(p_tracking_id text)
returns text
language sql
immutable
strict
set search_path = pg_catalog
as $$
  select upper(btrim(p_tracking_id));
$$;

revoke all on function public.normalize_tracking_id(text) from public;
grant execute on function public.normalize_tracking_id(text) to authenticated;

auto comment on function public.normalize_tracking_id(text) is
  'Canonicalizes a parcel tracking ID for global uniqueness checks: trim outer whitespace and normalize case.';

create or replace function public.validate_unique_tracking_id(
  p_tracking_id text,
  p_parcel_id uuid default null
)
returns table(
  valid boolean,
  tracking_id text,
  normalized_tracking_id text,
  conflicting_parcel_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_normalized text;
  v_conflict uuid;
begin
  if auth.uid() is null or public.app_role() not in ('operations','admin') then
    raise exception using errcode='42501', message='Operations or admin role required';
  end if;

  if btrim(coalesce(p_tracking_id, '')) = '' then
    raise exception using errcode='22023', message='Tracking ID is required';
  end if;

  v_normalized := public.normalize_tracking_id(p_tracking_id);

  select p.id
    into v_conflict
    from public.parcels p
   where p.normalized_tracking_id = v_normalized
     and (p_parcel_id is null or p.id <> p_parcel_id)
   limit 1;

  return query
  select v_conflict is null,
         btrim(p_tracking_id),
         v_normalized,
         v_conflict;
end;
$$;

revoke execute on function public.validate_unique_tracking_id(text,uuid) from anon;
revoke execute on function public.validate_unique_tracking_id(text,uuid) from public;
grant execute on function public.validate_unique_tracking_id(text,uuid) to authenticated;
