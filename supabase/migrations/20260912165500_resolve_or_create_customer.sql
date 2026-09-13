begin;

-- P5-T091: atomic resolve-or-create customer command.
-- Customer identity is keyed by the canonical UAE normalized phone established in T090.
create or replace function public.resolve_or_create_customer(
  p_name text,
  p_phone text,
  p_address text default null,
  p_city text default null
)
returns table (
  customer_id uuid,
  customer_code text,
  name text,
  phone text,
  normalized_phone text,
  address text,
  city text,
  created boolean
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_customer public.customers;
  v_normalized_phone text;
  v_created boolean := false;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then
    raise exception using errcode='42501', message='Authenticated operational role required';
  end if;

  if btrim(coalesce(p_name,'')) = '' then
    raise exception using errcode='22023', message='Customer name is required';
  end if;
  if btrim(coalesce(p_phone,'')) = '' then
    raise exception using errcode='22023', message='Customer phone is required';
  end if;

  v_normalized_phone := public.normalize_uae_phone(p_phone);
  if v_normalized_phone is null then
    raise exception using errcode='22023', message='Valid UAE phone is required';
  end if;

  -- Lock an existing identity before returning/updating it. If absent, the
  -- unique normalized_phone constraint serializes concurrent creates.
  select c.* into v_customer
  from public.customers c
  where c.normalized_phone = v_normalized_phone
  for update;

  if not found then
    begin
      insert into public.customers (name, phone, normalized_phone, address, city)
      values (
        btrim(p_name),
        btrim(p_phone),
        v_normalized_phone,
        nullif(btrim(coalesce(p_address,'')),''),
        nullif(btrim(coalesce(p_city,'')),'')
      )
      returning * into v_customer;
      v_created := true;
    exception when unique_violation then
      select c.* into v_customer
      from public.customers c
      where c.normalized_phone = v_normalized_phone
      for update;
      if not found then
        raise;
      end if;
    end;
  else
    update public.customers
    set name = btrim(p_name),
        phone = btrim(p_phone),
        address = nullif(btrim(coalesce(p_address,'')),''),
        city = nullif(btrim(coalesce(p_city,'')),''),
        updated_at = now()
    where id = v_customer.id
    returning * into v_customer;
  end if;

  insert into public.audit_logs (actor, action, entity_type, entity_id, after_data)
  values (
    auth.uid(),
    'resolve_or_create_customer',
    'customer',
    v_customer.id,
    jsonb_build_object(
      'customer_code', v_customer.customer_code,
      'normalized_phone', v_customer.normalized_phone,
      'created', v_created
    )
  );

  return query
  select v_customer.id, v_customer.customer_code, v_customer.name,
         v_customer.phone, v_customer.normalized_phone, v_customer.address,
         v_customer.city, v_created;
end;
$$;

revoke all on function public.resolve_or_create_customer(text,text,text,text) from public, anon;
grant execute on function public.resolve_or_create_customer(text,text,text,text) to authenticated;

commit;
