begin;

-- Runtime regression fix:
-- 1) PL/pgSQL output parameter "order_number" conflicts with the orders column
--    in CREATE ORDER's INSERT ... RETURNING clause.
-- 2) CREATE ORDER and customer lookup must use the canonical UAE phone normalizer.
-- 3) resolve_customer_by_phone lost its authenticated EXECUTE grant when the
--    privileged-function allowlist was hardened.

create or replace function public.create_order(
  p_customer_name text,
  p_phone text,
  p_address text,
  p_city text,
  p_original_amount numeric(12,2),
  p_items jsonb,
  p_notes text default null,
  p_idempotency_key text default null
)
returns table(order_id uuid,order_number text,customer_id uuid)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_customer_id uuid;
  v_order_id uuid;
  v_order_number text;
  v_normalized_phone text;
  v_item jsonb;
  v_line_no integer:=0;
  v_description text;
  v_quantity integer;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then
    raise exception using errcode='42501',message='Authenticated operational role required';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023',message='Idempotency key is required';
  end if;
  if btrim(coalesce(p_customer_name,''))='' then
    raise exception using errcode='22023',message='Customer name is required';
  end if;
  if btrim(coalesce(p_phone,''))='' then
    raise exception using errcode='22023',message='Customer phone is required';
  end if;
  if p_original_amount is null or p_original_amount<0 then
    raise exception using errcode='22023',message='Total Order Amount must be zero or greater';
  end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then
    raise exception using errcode='22023',message='At least one order item is required';
  end if;

  v_normalized_phone:=public.normalize_uae_phone(p_phone);
  if v_normalized_phone is null then
    raise exception using errcode='22023',message='Valid UAE phone is required';
  end if;

  v_hash:=md5(jsonb_build_object(
    'customer_name',btrim(p_customer_name),
    'phone',btrim(p_phone),
    'address',nullif(btrim(coalesce(p_address,'')),''),
    'city',nullif(btrim(coalesce(p_city,'')),''),
    'original_amount',p_original_amount,
    'items',p_items,
    'notes',p_notes
  )::text);

  select is_new,status,result
    into v_is_new,v_status,v_result
  from public.claim_command_idempotency('create_order',btrim(p_idempotency_key),v_hash);

  if not v_is_new then
    return query
      select (v_result->>'order_id')::uuid,
             v_result->>'order_number',
             (v_result->>'customer_id')::uuid;
    return;
  end if;

  select c.id into v_customer_id
  from public.customers c
  where c.normalized_phone=v_normalized_phone
  for update;

  if v_customer_id is null then
    begin
      insert into public.customers(name,phone,normalized_phone,address,city)
      values(
        btrim(p_customer_name),
        btrim(p_phone),
        v_normalized_phone,
        nullif(btrim(coalesce(p_address,'')),''),
        nullif(btrim(coalesce(p_city,'')),'')
      )
      returning id into v_customer_id;
    exception when unique_violation then
      select c.id into v_customer_id
      from public.customers c
      where c.normalized_phone=v_normalized_phone
      for update;
    end;
  else
    update public.customers
    set name=btrim(p_customer_name),
        phone=btrim(p_phone),
        address=nullif(btrim(coalesce(p_address,'')),''),
        city=nullif(btrim(coalesce(p_city,'')),''),
        updated_at=now()
    where id=v_customer_id;
  end if;

  insert into public.orders(customer_id,original_amount,lifecycle_state,notes,created_by) values(v_customer_id,p_original_amount,'Draft',p_notes,auth.uid())
  returning public.orders.id, public.orders.order_number
  into v_order_id,v_order_number;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_line_no:=v_line_no+1;
    v_description:=nullif(btrim(coalesce(v_item->>'description','')),'');
    if v_description is null or coalesce(v_item->>'quantity','') !~ '^[0-9]+
      raise exception using errcode='22023',
        message=format('Invalid order item at line %s',v_line_no);
    end if;
    v_quantity:=(v_item->>'quantity')::integer;
    if v_quantity<=0 then
      raise exception using errcode='22023',
        message=format('Invalid order item at line %s',v_line_no);
    end if;
    insert into public.order_items(order_id,line_no,description,quantity)
    values(v_order_id,v_line_no,v_description,v_quantity);
  end loop;

  insert into public.order_events(order_id,event_type,performed_by,metadata)
  values(v_order_id,'OrderCreated',auth.uid(),jsonb_build_object('lifecycle_state','Draft'));

  insert into public.audit_logs(actor,action,entity_type,entity_id,after_data)
  values(
    auth.uid(),
    'create_order',
    'order',
    v_order_id,
    jsonb_build_object(
      'order_number',v_order_number,
      'customer_id',v_customer_id,
      'original_amount',p_original_amount
    )
  );

  v_result:=jsonb_build_object(
    'order_id',v_order_id,
    'order_number',v_order_number,
    'customer_id',v_customer_id
  );
  perform public.complete_command_idempotency(
    'create_order',btrim(p_idempotency_key),v_result
  );

  return query select v_order_id,v_order_number,v_customer_id;
end;
$$;

revoke all on function public.create_order(text,text,text,text,numeric,jsonb,text,text) from public, anon;
grant execute on function public.create_order(text,text,text,text,numeric,jsonb,text,text) to authenticated;

create or replace function public.resolve_customer_by_phone(p_phone text)
returns table(
  customer_id uuid,
  customer_code text,
  name text,
  phone text,
  normalized_phone text,
  address text,
  city text
)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_normalized_phone text;
begin
  if auth.uid() is null or public.app_role() is null then
    raise exception using errcode='42501',message='Authentication required';
  end if;
  if btrim(coalesce(p_phone,''))='' then
    raise exception using errcode='22023',message='Phone is required';
  end if;

  v_normalized_phone:=public.normalize_uae_phone(p_phone);
  if v_normalized_phone is null then
    raise exception using errcode='22023',message='Valid UAE phone is required';
  end if;

  return query
    select c.id,c.customer_code,c.name,c.phone,c.normalized_phone,c.address,c.city
    from public.customers c
    where c.normalized_phone=v_normalized_phone;
end;
$$;

revoke all on function public.resolve_customer_by_phone(text) from public, anon;
grant execute on function public.resolve_customer_by_phone(text) to authenticated;

commit;
 then
      raise exception using errcode='22023',
        message=format('Invalid order item at line %s',v_line_no);
    end if;
    v_quantity:=(v_item->>'quantity')::integer;
    if v_quantity<=0 then
      raise exception using errcode='22023',
        message=format('Invalid order item at line %s',v_line_no);
    end if;
    insert into public.order_items(order_id,line_no,description,quantity)
    values(v_order_id,v_line_no,v_description,v_quantity);
  end loop;

  insert into public.order_events(order_id,event_type,performed_by,metadata)
  values(v_order_id,'OrderCreated',auth.uid(),jsonb_build_object('lifecycle_state','Draft'));

  insert into public.audit_logs(actor,action,entity_type,entity_id,after_data)
  values(
    auth.uid(),
    'create_order',
    'order',
    v_order_id,
    jsonb_build_object(
      'order_number',v_order_number,
      'customer_id',v_customer_id,
      'original_amount',p_original_amount
    )
  );

  v_result:=jsonb_build_object(
    'order_id',v_order_id,
    'order_number',v_order_number,
    'customer_id',v_customer_id
  );
  perform public.complete_command_idempotency(
    'create_order',btrim(p_idempotency_key),v_result
  );

  return query select v_order_id,v_order_number,v_customer_id;
end;
$$;

revoke all on function public.create_order(text,text,text,text,numeric,jsonb,text,text) from public, anon;
grant execute on function public.create_order(text,text,text,text,numeric,jsonb,text,text) to authenticated;

create or replace function public.resolve_customer_by_phone(p_phone text)
returns table(
  customer_id uuid,
  customer_code text,
  name text,
  phone text,
  normalized_phone text,
  address text,
  city text
)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_normalized_phone text;
begin
  if auth.uid() is null or public.app_role() is null then
    raise exception using errcode='42501',message='Authentication required';
  end if;
  if btrim(coalesce(p_phone,''))='' then
    raise exception using errcode='22023',message='Phone is required';
  end if;

  v_normalized_phone:=public.normalize_uae_phone(p_phone);
  if v_normalized_phone is null then
    raise exception using errcode='22023',message='Valid UAE phone is required';
  end if;

  return query
    select c.id,c.customer_code,c.name,c.phone,c.normalized_phone,c.address,c.city
    from public.customers c
    where c.normalized_phone=v_normalized_phone;
end;
$$;

revoke all on function public.resolve_customer_by_phone(text) from public, anon;
grant execute on function public.resolve_customer_by_phone(text) to authenticated;

commit;
 then
      raise exception using errcode='22023',
        message=format('Invalid order item at line %s',v_line_no);
    end if;
    v_quantity:=(v_item->>'quantity')::integer;
    if v_quantity<=0 then
      raise exception using errcode='22023',
        message=format('Invalid order item at line %s',v_line_no);
    end if;
    insert into public.order_items(order_id,line_no,description,quantity)
    values(v_order_id,v_line_no,v_description,v_quantity);
  end loop;

  insert into public.order_events(order_id,event_type,performed_by,metadata)
  values(v_order_id,'OrderCreated',auth.uid(),jsonb_build_object('lifecycle_state','Draft'));

  insert into public.audit_logs(actor,action,entity_type,entity_id,after_data)
  values(
    auth.uid(),
    'create_order',
    'order',
    v_order_id,
    jsonb_build_object(
      'order_number',v_order_number,
      'customer_id',v_customer_id,
      'original_amount',p_original_amount
    )
  );

  v_result:=jsonb_build_object(
    'order_id',v_order_id,
    'order_number',v_order_number,
    'customer_id',v_customer_id
  );
  perform public.complete_command_idempotency(
    'create_order',btrim(p_idempotency_key),v_result
  );

  return query select v_order_id,v_order_number,v_customer_id;
end;
$$;

revoke all on function public.create_order(text,text,text,text,numeric,jsonb,text,text) from public, anon;
grant execute on function public.create_order(text,text,text,text,numeric,jsonb,text,text) to authenticated;

create or replace function public.resolve_customer_by_phone(p_phone text)
returns table(
  customer_id uuid,
  customer_code text,
  name text,
  phone text,
  normalized_phone text,
  address text,
  city text
)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_normalized_phone text;
begin
  if auth.uid() is null or public.app_role() is null then
    raise exception using errcode='42501',message='Authentication required';
  end if;
  if btrim(coalesce(p_phone,''))='' then
    raise exception using errcode='22023',message='Phone is required';
  end if;

  v_normalized_phone:=public.normalize_uae_phone(p_phone);
  if v_normalized_phone is null then
    raise exception using errcode='22023',message='Valid UAE phone is required';
  end if;

  return query
    select c.id,c.customer_code,c.name,c.phone,c.normalized_phone,c.address,c.city
    from public.customers c
    where c.normalized_phone=v_normalized_phone;
end;
$$;

revoke all on function public.resolve_customer_by_phone(text) from public, anon;
grant execute on function public.resolve_customer_by_phone(text) to authenticated;

commit;
 then
      raise exception using errcode='22023',
        message=format('Invalid order item at line %s',v_line_no);
    end if;
    v_quantity:=(v_item->>'quantity')::integer;
    if v_quantity<=0 then
      raise exception using errcode='22023',
        message=format('Invalid order item at line %s',v_line_no);
    end if;
    insert into public.order_items(order_id,line_no,description,quantity)
    values(v_order_id,v_line_no,v_description,v_quantity);
  end loop;

  insert into public.order_events(order_id,event_type,performed_by,metadata)
  values(v_order_id,'OrderCreated',auth.uid(),jsonb_build_object('lifecycle_state','Draft'));

  insert into public.audit_logs(actor,action,entity_type,entity_id,after_data)
  values(
    auth.uid(),
    'create_order',
    'order',
    v_order_id,
    jsonb_build_object(
      'order_number',v_order_number,
      'customer_id',v_customer_id,
      'original_amount',p_original_amount
    )
  );

  v_result:=jsonb_build_object(
    'order_id',v_order_id,
    'order_number',v_order_number,
    'customer_id',v_customer_id
  );
  perform public.complete_command_idempotency(
    'create_order',btrim(p_idempotency_key),v_result
  );

  return query select v_order_id,v_order_number,v_customer_id;
end;
$$;

revoke all on function public.create_order(text,text,text,text,numeric,jsonb,text,text) from public, anon;
grant execute on function public.create_order(text,text,text,text,numeric,jsonb,text,text) to authenticated;

create or replace function public.resolve_customer_by_phone(p_phone text)
returns table(
  customer_id uuid,
  customer_code text,
  name text,
  phone text,
  normalized_phone text,
  address text,
  city text
)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_normalized_phone text;
begin
  if auth.uid() is null or public.app_role() is null then
    raise exception using errcode='42501',message='Authentication required';
  end if;
  if btrim(coalesce(p_phone,''))='' then
    raise exception using errcode='22023',message='Phone is required';
  end if;

  v_normalized_phone:=public.normalize_uae_phone(p_phone);
  if v_normalized_phone is null then
    raise exception using errcode='22023',message='Valid UAE phone is required';
  end if;

  return query
    select c.id,c.customer_code,c.name,c.phone,c.normalized_phone,c.address,c.city
    from public.customers c
    where c.normalized_phone=v_normalized_phone;
end;
$$;

revoke all on function public.resolve_customer_by_phone(text) from public, anon;
grant execute on function public.resolve_customer_by_phone(text) to authenticated;

commit;
