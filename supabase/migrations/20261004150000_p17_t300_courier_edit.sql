-- P17-T300: trusted Admin-only courier master-data edit command.
-- Preserves the existing courier UUID, courier_code, active state, and
-- browser SELECT-only boundary on public.shippers.

create or replace function public.update_courier(
  p_courier_id uuid,
  p_name text,
  p_idempotency_key text,
  p_contact_name text default null,
  p_contact_phone text default null,
  p_contact_email text default null,
  p_address text default null,
  p_notes text default null
)
returns table(
  courier_id uuid,
  courier_code text,
  name text,
  contact_name text,
  contact_phone text,
  contact_email text,
  address text,
  notes text,
  active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_name text;
  v_contact_name text;
  v_contact_phone text;
  v_contact_email text;
  v_address text;
  v_notes text;
  v_idempotency_key text;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
  v_before jsonb;
  v_id uuid;
  v_code text;
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

  v_name := nullif(btrim(coalesce(p_name, '')), '');
  if v_name is null then
    raise exception using errcode = '22004', message = 'name_required';
  end if;
  if char_length(v_name) > 200 then
    raise exception using errcode = '22023', message = 'name_too_long';
  end if;

  v_idempotency_key := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  if v_idempotency_key is null then
    raise exception using errcode = '22023', message = 'idempotency_key_required';
  end if;
  if char_length(v_idempotency_key) > 200 then
    raise exception using errcode = '22023', message = 'idempotency_key_too_long';
  end if;

  v_contact_name := nullif(btrim(coalesce(p_contact_name, '')), '');
  v_contact_phone := nullif(btrim(coalesce(p_contact_phone, '')), '');
  v_contact_email := nullif(lower(btrim(coalesce(p_contact_email, ''))), '');
  v_address := nullif(btrim(coalesce(p_address, '')), '');
  v_notes := nullif(btrim(coalesce(p_notes, '')), '');

  if v_contact_name is not null and char_length(v_contact_name) > 200 then
    raise exception using errcode = '22023', message = 'contact_name_too_long';
  end if;
  if v_contact_phone is not null and char_length(v_contact_phone) > 50 then
    raise exception using errcode = '22023', message = 'contact_phone_too_long';
  end if;
  if v_contact_email is not null and char_length(v_contact_email) > 320 then
    raise exception using errcode = '22023', message = 'contact_email_too_long';
  end if;
  if v_address is not null and char_length(v_address) > 500 then
    raise exception using errcode = '22023', message = 'address_too_long';
  end if;
  if v_notes is not null and char_length(v_notes) > 2000 then
    raise exception using errcode = '22023', message = 'notes_too_long';
  end if;

  select
    s.id,
    s.courier_code,
    s.name,
    s.contact_name,
    s.contact_phone,
    s.contact_email,
    s.address,
    s.notes,
    s.active,
    s.created_at,
    s.updated_at
  into
    v_id,
    v_code,
    v_name,
    v_contact_name,
    v_contact_phone,
    v_contact_email,
    v_address,
    v_notes,
    v_active,
    v_created_at,
    v_updated_at
  from public.shippers s
  where s.id = p_courier_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'courier_not_found';
  end if;

  v_before := jsonb_build_object(
    'courier_code', v_code,
    'name', v_name,
    'contact_name', v_contact_name,
    'contact_phone', v_contact_phone,
    'contact_email', v_contact_email,
    'address', v_address,
    'notes', v_notes,
    'active', v_active
  );

  v_hash := md5(jsonb_build_object(
    'courier_id', p_courier_id,
    'name', nullif(btrim(coalesce(p_name, '')), ''),
    'contact_name', nullif(btrim(coalesce(p_contact_name, '')), ''),
    'contact_phone', nullif(btrim(coalesce(p_contact_phone, '')), ''),
    'contact_email', nullif(lower(btrim(coalesce(p_contact_email, ''))), ''),
    'address', nullif(btrim(coalesce(p_address, '')), ''),
    'notes', nullif(btrim(coalesce(p_notes, '')), '')
  )::text);

  select c.is_new, c.status, c.result
    into v_is_new, v_status, v_result
  from public.claim_command_idempotency(
    'update_courier',
    v_idempotency_key,
    v_hash
  ) c;

  if not v_is_new then
    return query
    select
      (v_result->>'courier_id')::uuid,
      v_result->>'courier_code',
      v_result->>'name',
      v_result->>'contact_name',
      v_result->>'contact_phone',
      v_result->>'contact_email',
      v_result->>'address',
      v_result->>'notes',
      (v_result->>'active')::boolean,
      (v_result->>'created_at')::timestamptz,
      (v_result->>'updated_at')::timestamptz;
    return;
  end if;

  update public.shippers
  set
    name = nullif(btrim(coalesce(p_name, '')), ''),
    contact_name = nullif(btrim(coalesce(p_contact_name, '')), ''),
    contact_phone = nullif(btrim(coalesce(p_contact_phone, '')), ''),
    contact_email = nullif(lower(btrim(coalesce(p_contact_email, ''))), ''),
    address = nullif(btrim(coalesce(p_address, '')), ''),
    notes = nullif(btrim(coalesce(p_notes, '')), '')
  where id = p_courier_id
  returning
    id,
    courier_code,
    name,
    contact_name,
    contact_phone,
    contact_email,
    address,
    notes,
    active,
    created_at,
    updated_at
  into
    v_id,
    v_code,
    v_name,
    v_contact_name,
    v_contact_phone,
    v_contact_email,
    v_address,
    v_notes,
    v_active,
    v_created_at,
    v_updated_at;

  insert into public.audit_logs(
    actor,
    action,
    entity_type,
    entity_id,
    before_data,
    after_data
  ) values (
    auth.uid(),
    'update_courier',
    'shipper',
    v_id,
    v_before,
    jsonb_build_object(
      'courier_code', v_code,
      'name', v_name,
      'contact_name', v_contact_name,
      'contact_phone', v_contact_phone,
      'contact_email', v_contact_email,
      'address', v_address,
      'notes', v_notes,
      'active', v_active
    )
  );

  v_result := jsonb_build_object(
    'courier_id', v_id,
    'courier_code', v_code,
    'name', v_name,
    'contact_name', v_contact_name,
    'contact_phone', v_contact_phone,
    'contact_email', v_contact_email,
    'address', v_address,
    'notes', v_notes,
    'active', v_active,
    'created_at', v_created_at,
    'updated_at', v_updated_at
  );

  perform public.complete_command_idempotency(
    'update_courier',
    v_idempotency_key,
    v_result
  );

  return query
  select
    v_id,
    v_code,
    v_name,
    v_contact_name,
    v_contact_phone,
    v_contact_email,
    v_address,
    v_notes,
    v_active,
    v_created_at,
    v_updated_at;
end;
$$;

revoke all on function public.update_courier(uuid, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.update_courier(uuid, text, text, text, text, text, text, text) to authenticated;
