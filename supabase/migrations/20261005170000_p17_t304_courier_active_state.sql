-- P17-T304: trusted Admin-only courier active/inactive state command.
-- Reuses public.shippers.active; preserves courier identity and parcel relationships.

create or replace function public.set_courier_active(
  p_courier_id uuid,
  p_active boolean,
  p_idempotency_key text
)
returns table(
  courier_id uuid,
  courier_code text,
  name text,
  active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_idempotency_key text;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
  v_before jsonb;
  v_id uuid;
  v_code text;
  v_name text;
  v_active boolean;
  v_created_at timestamptz;
  v_updated_at timestamptz;
begin
  if auth.uid() is null or public.app_role() <> 'admin' then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  if p_courier_id is null then
    raise exception using errcode = '22004', message = 'courier_id_required';
  end if;

  if p_active is null then
    raise exception using errcode = '22004', message = 'active_required';
  end if;

  v_idempotency_key := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  if v_idempotency_key is null then
    raise exception using errcode = '22023', message = 'idempotency_key_required';
  end if;
  if char_length(v_idempotency_key) > 200 then
    raise exception using errcode = '22023', message = 'idempotency_key_too_long';
  end if;

  select
    s.id,
    s.courier_code,
    s.name,
    s.active,
    s.created_at,
    s.updated_at
  into
    v_id,
    v_code,
    v_name,
    v_active,
    v_created_at,
    v_updated_at
  from public.shippers s
  where s.id = p_courier_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'courier_not_found';
  end if;

  v_before := jsonb_build_object(
    'courier_code', v_code,
    'name', v_name,
    'active', v_active
  );

  v_hash := md5(jsonb_build_object(
    'courier_id', p_courier_id,
    'active', p_active
  )::text);

  select c.is_new, c.status, c.result
    into v_is_new, v_status, v_result
  from public.claim_command_idempotency(
    'set_courier_active',
    v_idempotency_key,
    v_hash
  ) c;

  if not v_is_new then
    return query
    select
      (v_result->>'courier_id')::uuid,
      v_result->>'courier_code',
      v_result->>'name',
      (v_result->>'active')::boolean,
      (v_result->>'created_at')::timestamptz,
      (v_result->>'updated_at')::timestamptz;
    return;
  end if;

  if v_active is distinct from p_active then
    update public.shippers
    set active = p_active
    where id = p_courier_id
    returning public.shippers.id, public.shippers.courier_code, public.shippers.name, public.shippers.active, public.shippers.created_at, public.shippers.updated_at
      into v_id, v_code, v_name, v_active, v_created_at, v_updated_at;

    insert into public.audit_logs(
      actor,
      action,
      entity_type,
      entity_id,
      before_data,
      after_data
    ) values (
      auth.uid(),
      case when p_active then 'activate_courier' else 'deactivate_courier' end,
      'shipper',
      v_id,
      v_before,
      jsonb_build_object(
        'courier_code', v_code,
        'name', v_name,
        'active', v_active
      )
    );
  end if;

  v_result := jsonb_build_object(
    'courier_id', v_id,
    'courier_code', v_code,
    'name', v_name,
    'active', v_active,
    'created_at', v_created_at,
    'updated_at', v_updated_at
  );

  perform public.complete_command_idempotency(
    'set_courier_active',
    v_idempotency_key,
    v_result
  );

  return query
  select
    v_id,
    v_code,
    v_name,
    v_active,
    v_created_at,
    v_updated_at;
end;
$$;

revoke all on function public.set_courier_active(uuid, boolean, text) from public, anon;
grant execute on function public.set_courier_active(uuid, boolean, text) to authenticated;
