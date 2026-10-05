begin;

-- P17-T305: parcel-level courier assignment and reassignment.
-- Keep public.parcels.shipper_id as the single source of truth.
-- No order-level courier relationship is introduced.
--
-- Assignment/reassignment is permitted only while the parcel is Prepared.
-- The target courier must be active for a new/different assignment.
-- Existing tracking ownership is not changed by this command.

create or replace function public.assign_parcel_shipper(
  p_parcel_id uuid,
  p_shipper_id uuid,
  p_idempotency_key text
)
returns table(
  parcel_id uuid,
  parcel_number text,
  shipper_id uuid,
  shipper_name text,
  state text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parcel_number text;
  v_order_id uuid;
  v_state text;
  v_existing_shipper_id uuid;
  v_shipper_name text;
  v_shipper_active boolean;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('operations','admin') then
    raise exception using
      errcode = '42501',
      message = 'Operations or admin role required';
  end if;

  if p_parcel_id is null then
    raise exception using
      errcode = '22023',
      message = 'Parcel ID is required';
  end if;

  if p_shipper_id is null then
    raise exception using
      errcode = '22023',
      message = 'Shipper ID is required';
  end if;

  if pg_catalog.btrim(coalesce(p_idempotency_key, '')) = '' then
    raise exception using
      errcode = '22023',
      message = 'Idempotency key is required';
  end if;

  v_hash := pg_catalog.md5(
    pg_catalog.jsonb_build_object(
      'parcel_id', p_parcel_id,
      'shipper_id', p_shipper_id
    )::text
  );

  select is_new, status, result
    into v_is_new, v_status, v_result
  from public.claim_command_idempotency(
    'assign_parcel_shipper',
    pg_catalog.btrim(p_idempotency_key),
    v_hash
  );

  if not v_is_new then
    return query
      select
        (v_result->>'parcel_id')::uuid,
        v_result->>'parcel_number',
        (v_result->>'shipper_id')::uuid,
        v_result->>'shipper_name',
        v_result->>'state';
    return;
  end if;

  select
      p.parcel_number,
      p.order_id,
      p.state,
      p.shipper_id
    into
      v_parcel_number,
      v_order_id,
      v_state,
      v_existing_shipper_id
  from public.parcels p
  where p.id = p_parcel_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Parcel not found';
  end if;

  if v_state <> 'Prepared' then
    raise exception using
      errcode = 'P0001',
      message = 'Courier assignment is permitted only while parcel is Prepared';
  end if;

  -- Lock the target courier before checking active state so deactivation
  -- cannot race with a successful new assignment.
  select
      s.name,
      s.active
    into
      v_shipper_name,
      v_shipper_active
  from public.shippers s
  where s.id = p_shipper_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Courier not found';
  end if;

  -- Re-selecting the already assigned courier is a safe no-op. This also
  -- preserves historical assignments to a courier that was later deactivated.
  if v_existing_shipper_id is not null
     and v_existing_shipper_id = p_shipper_id then

    v_result := pg_catalog.jsonb_build_object(
      'parcel_id', p_parcel_id,
      'parcel_number', v_parcel_number,
      'shipper_id', p_shipper_id,
      'shipper_name', v_shipper_name,
      'state', v_state
    );

    perform public.complete_command_idempotency(
      'assign_parcel_shipper',
      pg_catalog.btrim(p_idempotency_key),
      v_result
    );

    return query
      select
        p_parcel_id,
        v_parcel_number,
        p_shipper_id,
        v_shipper_name,
        v_state;
    return;
  end if;

  if v_shipper_active is distinct from true then
    raise exception using
      errcode = 'P0001',
      message = 'Active courier is required for a new or reassigned parcel';
  end if;

  update public.parcels
  set
    shipper_id = p_shipper_id,
    updated_at = pg_catalog.now()
  where id = p_parcel_id;

  if v_existing_shipper_id is null then
    insert into public.order_events(
      order_id,
      parcel_id,
      event_type,
      performed_by,
      metadata
    )
    values(
      v_order_id,
      p_parcel_id,
      'ShipperAssigned',
      auth.uid(),
      pg_catalog.jsonb_build_object(
        'parcel_number', v_parcel_number,
        'shipper_id', p_shipper_id,
        'shipper_name', v_shipper_name,
        'from_shipper_id', null,
        'to_shipper_id', p_shipper_id,
        'state', v_state
      )
    );
  else
    insert into public.order_events(
      order_id,
      parcel_id,
      event_type,
      performed_by,
      metadata
    )
    values(
      v_order_id,
      p_parcel_id,
      'ShipperReassigned',
      auth.uid(),
      pg_catalog.jsonb_build_object(
        'parcel_number', v_parcel_number,
        'from_shipper_id', v_existing_shipper_id,
        'to_shipper_id', p_shipper_id,
        'to_shipper_name', v_shipper_name,
        'state', v_state
      )
    );
  end if;

  insert into public.audit_logs(
    actor,
    action,
    entity_type,
    entity_id,
    before_data,
    after_data
  )
  values(
    auth.uid(),
    case
      when v_existing_shipper_id is null
        then 'assign_parcel_shipper'
      else 'reassign_parcel_shipper'
    end,
    'parcel',
    p_parcel_id,
    pg_catalog.jsonb_build_object(
      'shipper_id', v_existing_shipper_id
    ),
    pg_catalog.jsonb_build_object(
      'shipper_id', p_shipper_id,
      'shipper_name', v_shipper_name
    )
  );

  v_result := pg_catalog.jsonb_build_object(
    'parcel_id', p_parcel_id,
    'parcel_number', v_parcel_number,
    'shipper_id', p_shipper_id,
    'shipper_name', v_shipper_name,
    'state', v_state
  );

  perform public.complete_command_idempotency(
    'assign_parcel_shipper',
    pg_catalog.btrim(p_idempotency_key),
    v_result
  );

  return query
    select
      p_parcel_id,
      v_parcel_number,
      p_shipper_id,
      v_shipper_name,
      v_state;
end;
$$;

revoke execute on function public.assign_parcel_shipper(uuid,uuid,text) from public;
revoke execute on function public.assign_parcel_shipper(uuid,uuid,text) from anon;
grant execute on function public.assign_parcel_shipper(uuid,uuid,text) to authenticated;

commit;
