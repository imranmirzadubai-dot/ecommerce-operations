-- E-Commerce Operations MVP v4.0
-- Enforce deterministic retries for state-changing core commands.

-- Replace the pre-idempotency signatures so callers cannot bypass the contract.
drop function if exists public.create_order(text,text,text,text,numeric,jsonb,text);
drop function if exists public.confirm_order(uuid);
drop function if exists public.cancel_order(uuid);

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
language plpgsql security definer set search_path=pg_catalog, public
as $$
declare
  v_customer_id uuid; v_order_id uuid; v_order_number text; v_normalized_phone text;
  v_item jsonb; v_line_no integer:=0; v_description text; v_quantity integer;
  v_hash text; v_is_new boolean; v_status text; v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then raise exception using errcode='42501',message='Authenticated operational role required'; end if;
  if btrim(coalesce(p_idempotency_key,''))='' then raise exception using errcode='22023',message='Idempotency key is required'; end if;
  if btrim(coalesce(p_customer_name,''))='' then raise exception using errcode='22023',message='Customer name is required'; end if;
  if btrim(coalesce(p_phone,''))='' then raise exception using errcode='22023',message='Customer phone is required'; end if;
  if p_original_amount is null or p_original_amount<0 then raise exception using errcode='22023',message='Total Order Amount must be zero or greater'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception using errcode='22023',message='At least one order item is required'; end if;
  v_normalized_phone:=regexp_replace(p_phone,'[^0-9+]','','g');
  if v_normalized_phone='' then raise exception using errcode='22023',message='Phone is invalid'; end if;

  v_hash:=md5(jsonb_build_object('customer_name',btrim(p_customer_name),'phone',btrim(p_phone),'address',nullif(btrim(coalesce(p_address,'')),''),'city',nullif(btrim(coalesce(p_city,'')),''),'original_amount',p_original_amount,'items',p_items,'notes',p_notes)::text);
  select is_new,status,result into v_is_new,v_status,v_result from public.claim_command_idempotency('create_order',btrim(p_idempotency_key),v_hash);
  if not v_is_new then
    return query select (v_result->>'order_id')::uuid,v_result->>'order_number',(v_result->>'customer_id')::uuid;
    return;
  end if;

  select c.id into v_customer_id from public.customers c where c.normalized_phone=v_normalized_phone for update;
  if v_customer_id is null then
    begin
      insert into public.customers(name,phone,normalized_phone,address,city) values(btrim(p_customer_name),btrim(p_phone),v_normalized_phone,nullif(btrim(coalesce(p_address,'')),''),nullif(btrim(coalesce(p_city,'')),'')) returning id into v_customer_id;
    exception when unique_violation then
      select c.id into v_customer_id from public.customers c where c.normalized_phone=v_normalized_phone for update;
    end;
  else
    update public.customers set name=btrim(p_customer_name),phone=btrim(p_phone),address=nullif(btrim(coalesce(p_address,'')),''),city=nullif(btrim(coalesce(p_city,'')),''),updated_at=now() where id=v_customer_id;
  end if;

  insert into public.orders(customer_id,original_amount,lifecycle_state,notes,created_by) values(v_customer_id,p_original_amount,'Draft',p_notes,auth.uid()) returning id,order_number into v_order_id,v_order_number;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_line_no:=v_line_no+1; v_description:=nullif(btrim(coalesce(v_item->>'description','')),'');
    if v_description is null or coalesce(v_item->>'quantity','') !~ '^\\d+$' then raise exception using errcode='22023',message=format('Invalid order item at line %s',v_line_no); end if;
    v_quantity:=(v_item->>'quantity')::integer;
    if v_quantity<=0 then raise exception using errcode='22023',message=format('Invalid order item at line %s',v_line_no); end if;
    insert into public.order_items(order_id,line_no,description,quantity) values(v_order_id,v_line_no,v_description,v_quantity);
  end loop;
  insert into public.order_events(order_id,event_type,performed_by,metadata) values(v_order_id,'OrderCreated',auth.uid(),jsonb_build_object('lifecycle_state','Draft'));
  insert into public.audit_logs(actor,action,entity_type,entity_id,after_data) values(auth.uid(),'create_order','order',v_order_id,jsonb_build_object('order_number',v_order_number,'customer_id',v_customer_id,'original_amount',p_original_amount));
  v_result:=jsonb_build_object('order_id',v_order_id,'order_number',v_order_number,'customer_id',v_customer_id);
  perform public.complete_command_idempotency('create_order',btrim(p_idempotency_key),v_result);
  return query select v_order_id,v_order_number,v_customer_id;
end; $$;
revoke all on function public.create_order(text,text,text,text,numeric,jsonb,text,text) from public;
grant execute on function public.create_order(text,text,text,text,numeric,jsonb,text,text) to authenticated;

create or replace function public.confirm_order(p_order_id uuid,p_idempotency_key text)
returns table(order_id uuid,order_number text,lifecycle_state text)
language plpgsql security definer set search_path=pg_catalog, public
as $$
declare v_state text; v_order_number text; v_hash text; v_is_new boolean; v_status text; v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then raise exception using errcode='42501',message='Authenticated operational role required'; end if;
  if p_idempotency_key is null or btrim(p_idempotency_key)='' then raise exception using errcode='22023',message='Idempotency key is required'; end if;
  v_hash:=md5(jsonb_build_object('order_id',p_order_id)::text);
  select is_new,status,result into v_is_new,v_status,v_result from public.claim_command_idempotency('confirm_order',btrim(p_idempotency_key),v_hash);
  if not v_is_new then return query select (v_result->>'order_id')::uuid,v_result->>'order_number',v_result->>'lifecycle_state'; return; end if;
  select lifecycle_state,order_number into v_state,v_order_number from public.orders where id=p_order_id for update;
  if not found then raise exception using errcode='P0002',message='Order not found'; end if;
  if v_state<>'Draft' then raise exception using errcode='P0001',message='Only Draft orders can be confirmed'; end if;
  if not exists(select 1 from public.order_items where order_id=p_order_id) then raise exception using errcode='P0001',message='Order must contain at least one item'; end if;
  update public.orders set lifecycle_state='Confirmed',updated_at=now() where id=p_order_id;
  insert into public.order_events(order_id,event_type,performed_by,metadata) values(p_order_id,'OrderConfirmed',auth.uid(),jsonb_build_object('from','Draft','to','Confirmed'));
  insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data) values(auth.uid(),'confirm_order','order',p_order_id,jsonb_build_object('lifecycle_state','Draft'),jsonb_build_object('lifecycle_state','Confirmed'));
  v_result:=jsonb_build_object('order_id',p_order_id,'order_number',v_order_number,'lifecycle_state','Confirmed');
  perform public.complete_command_idempotency('confirm_order',btrim(p_idempotency_key),v_result);
  return query select p_order_id,v_order_number,'Confirmed'::text;
end; $$;
revoke all on function public.confirm_order(uuid,text) from public;
grant execute on function public.confirm_order(uuid,text) to authenticated;

create or replace function public.cancel_order(p_order_id uuid,p_idempotency_key text)
returns table(order_id uuid,order_number text,lifecycle_state text)
language plpgsql security definer set search_path=pg_catalog, public
as $$
declare v_state text; v_order_number text; v_hash text; v_is_new boolean; v_status text; v_result jsonb;
begin
  if auth.uid() is null or public.app_role() is null then raise exception using errcode='42501',message='Authentication required'; end if;
  if p_idempotency_key is null or btrim(p_idempotency_key)='' then raise exception using errcode='22023',message='Idempotency key is required'; end if;
  v_hash:=md5(jsonb_build_object('order_id',p_order_id)::text);
  select is_new,status,result into v_is_new,v_status,v_result from public.claim_command_idempotency('cancel_order',btrim(p_idempotency_key),v_hash);
  if not v_is_new then return query select (v_result->>'order_id')::uuid,v_result->>'order_number',v_result->>'lifecycle_state'; return; end if;
  select lifecycle_state,order_number into v_state,v_order_number from public.orders where id=p_order_id for update;
  if not found then raise exception using errcode='P0002',message='Order not found'; end if;
  if v_state not in ('Draft','Confirmed') then raise exception using errcode='P0001',message='Order cannot be cancelled after parcel dispatch or later'; end if;
  if exists(select 1 from public.parcels where order_id=p_order_id and state not in ('Prepared','Cancelled')) then raise exception using errcode='P0001',message='Order cannot be cancelled after a parcel reaches dispatch or later'; end if;
  update public.orders set lifecycle_state='Cancelled',updated_at=now() where id=p_order_id;
  update public.parcel_items pi set allocation_state='Reversed',updated_at=now() from public.parcels p where p.id=pi.parcel_id and p.order_id=p_order_id and p.state='Prepared' and pi.allocation_state='Allocated';
  update public.parcels set state='Cancelled',updated_at=now() where order_id=p_order_id and state='Prepared';
  insert into public.order_events(order_id,event_type,performed_by,metadata) values(p_order_id,'OrderCancelled',auth.uid(),jsonb_build_object('from',v_state,'to','Cancelled','allocation_reversal','applied'));
  insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data) values(auth.uid(),'cancel_order','order',p_order_id,jsonb_build_object('lifecycle_state',v_state),jsonb_build_object('lifecycle_state','Cancelled'));
  v_result:=jsonb_build_object('order_id',p_order_id,'order_number',v_order_number,'lifecycle_state','Cancelled');
  perform public.complete_command_idempotency('cancel_order',btrim(p_idempotency_key),v_result);
  return query select p_order_id,v_order_number,'Cancelled'::text;
end; $$;
revoke all on function public.cancel_order(uuid,text) from public;
grant execute on function public.cancel_order(uuid,text) to authenticated;
