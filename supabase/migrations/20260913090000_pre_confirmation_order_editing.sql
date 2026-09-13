-- P5-T096: Pre-confirmation Draft Order editing.
-- One transactional command updates the editable Draft-order fields and items atomically.
-- Confirmed and later lifecycle states are immutable through this command.

create or replace function public.update_order(
  p_order_id uuid,
  p_customer_name text,
  p_phone text,
  p_address text,
  p_city text,
  p_original_amount numeric(12,2),
  p_items jsonb,
  p_notes text default null,
  p_idempotency_key text default null
)
returns table(order_id uuid, order_number text, lifecycle_state text)
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_state text;
  v_order_number text;
  v_customer_id uuid;
  v_normalized_phone text;
  v_item jsonb;
  v_line_no integer := 0;
  v_description text;
  v_quantity integer;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then
    raise exception using errcode='42501', message='Authenticated operational role required';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;
  if p_order_id is null then
    raise exception using errcode='22023', message='Order ID is required';
  end if;
  if btrim(coalesce(p_customer_name,''))='' then
    raise exception using errcode='22023', message='Customer name is required';
  end if;
  if btrim(coalesce(p_phone,''))='' then
    raise exception using errcode='22023', message='Customer phone is required';
  end if;
  if p_original_amount is null or p_original_amount < 0 then
    raise exception using errcode='22023', message='Total Order Amount must be zero or greater';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then
    raise exception using errcode='22023', message='At least one order item is required';
  end if;

  v_normalized_phone := regexp_replace(p_phone,'[^0-9+]','','g');
  if v_normalized_phone='' then
    raise exception using errcode='22023', message='Phone is invalid';
  end if;

  v_hash := md5(jsonb_build_object(
    'order_id', p_order_id,
    'customer_name', btrim(p_customer_name),
    'phone', btrim(p_phone),
    'address', nullif(btrim(coalesce(p_address,'')),''),
    'city', nullif(btrim(coalesce(p_city,'')),''),
    'original_amount', p_original_amount,
    'items', p_items,
    'notes', p_notes
  )::text);

  select is_new,status,result into v_is_new,v_status,v_result
  from public.claim_command_idempotency('update_order',btrim(p_idempotency_key),v_hash);
  if not v_is_new then
    return query select (v_result->>'order_id')::uuid,v_result->>'order_number',v_result->>'lifecycle_state';
    return;
  end if;

  select lifecycle_state,order_number,customer_id
    into v_state,v_order_number,v_customer_id
    from public.orders
   where id=p_order_id
   for update;
  if not found then
    raise exception using errcode='P0002', message='Order not found';
  end if;
  if v_state <> 'Draft' then
    raise exception using errcode='P0001', message='Only Draft orders can be edited before confirmation';
  end if;

  -- Validate every item before any business row is mutated.
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_line_no := v_line_no + 1;
    v_description := nullif(btrim(coalesce(v_item->>'description','')),'');
    if v_description is null or coalesce(v_item->>'quantity','') !~ '^\d+$' then
      raise exception using errcode='22023', message=format('Invalid order item at line %s',v_line_no);
    end if;
    v_quantity := (v_item->>'quantity')::integer;
    if v_quantity <= 0 then
      raise exception using errcode='22023', message=format('Invalid order item at line %s',v_line_no);
    end if;
  end loop;

  select id into v_customer_id from public.customers where normalized_phone=v_normalized_phone for update;
  if v_customer_id is null then
    begin
      insert into public.customers(name,phone,normalized_phone,address,city)
      values(
        btrim(p_customer_name), btrim(p_phone), v_normalized_phone,
        nullif(btrim(coalesce(p_address,'')),''), nullif(btrim(coalesce(p_city,'')),'')
      ) returning id into v_customer_id;
    exception when unique_violation then
      select id into v_customer_id from public.customers where normalized_phone=v_normalized_phone for update;
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

  update public.orders
     set customer_id=v_customer_id,
         original_amount=p_original_amount,
         notes=p_notes,
         updated_at=now()
   where id=p_order_id;

  delete from public.order_items where order_id=p_order_id;
  v_line_no := 0;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_line_no := v_line_no + 1;
    insert into public.order_items(order_id,line_no,description,quantity)
    values(p_order_id,v_line_no,btrim(v_item->>'description'),(v_item->>'quantity')::integer);
  end loop;

  insert into public.order_events(order_id,event_type,performed_by,metadata)
  values(p_order_id,'OrderUpdated',auth.uid(),jsonb_build_object('lifecycle_state','Draft','item_count',jsonb_array_length(p_items)));

  insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
  values(
    auth.uid(),'update_order','order',p_order_id,
    jsonb_build_object('lifecycle_state','Draft'),
    jsonb_build_object('order_number',v_order_number,'customer_id',v_customer_id,'original_amount',p_original_amount,'item_count',jsonb_array_length(p_items))
  );

  v_result := jsonb_build_object('order_id',p_order_id,'order_number',v_order_number,'lifecycle_state','Draft');
  perform public.complete_command_idempotency('update_order',btrim(p_idempotency_key),v_result);

  return query select p_order_id,v_order_number,'Draft'::text;
end; $$;

revoke all on function public.update_order(uuid,text,text,text,text,numeric,jsonb,text,text) from public;
revoke execute on function public.update_order(uuid,text,text,text,text,numeric,jsonb,text,text) from anon;
grant execute on function public.update_order(uuid,text,text,text,text,numeric,jsonb,text,text) to authenticated;
