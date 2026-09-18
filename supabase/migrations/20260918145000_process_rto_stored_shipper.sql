-- P10-T161/T162: RTO processing wrapper with automatic stored-shipper resolution.
-- The authoritative lifecycle mutation remains record_delivery_outcome('RTO').
-- This command adds no alternate parcel-state mutation path.

create or replace function public.process_rto(
  p_parcel_id uuid,
  p_note text,
  p_idempotency_key text
)
returns table(
  parcel_id uuid,
  parcel_number text,
  order_id uuid,
  shipper_id uuid,
  shipper_name text,
  tracking_id text,
  state text,
  rto_at timestamptz,
  outcome_id uuid
)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_outcome_id uuid;
  v_parcel_number text;
  v_order_id uuid;
  v_shipper_id uuid;
  v_shipper_name text;
  v_tracking_id text;
  v_state text;
  v_rto_at timestamptz;
begin
  if auth.uid() is null or public.app_role() not in ('operations','admin') then
    raise exception using errcode='42501', message='Operations or admin role required';
  end if;
  if p_parcel_id is null then
    raise exception using errcode='22023', message='Parcel ID is required';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  select r.outcome_id
    into v_outcome_id
  from public.record_delivery_outcome(p_parcel_id,'RTO',p_note,btrim(p_idempotency_key)) r;

  select p.parcel_number,p.order_id,p.shipper_id,s.name,p.tracking_id,p.state,p.rto_at
    into v_parcel_number,v_order_id,v_shipper_id,v_shipper_name,v_tracking_id,v_state,v_rto_at
  from public.parcels p
  left join public.shippers s on s.id=p.shipper_id
  where p.id=p_parcel_id;

  if not found then
    raise exception using errcode='P0002', message='Parcel not found';
  end if;

  return query
    select p_parcel_id,v_parcel_number,v_order_id,v_shipper_id,v_shipper_name,
           v_tracking_id,v_state,v_rto_at,v_outcome_id;
end;
$$;

revoke execute on function public.process_rto(uuid,text,text) from public, anon;
grant execute on function public.process_rto(uuid,text,text) to authenticated;

comment on function public.process_rto(uuid,text,text) is
  'P10-T161/T162: processes RTO through the authoritative delivery-outcome command and returns the parcel-stored historical shipper automatically.';
