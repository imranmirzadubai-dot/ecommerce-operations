-- P17 runtime hardening: qualify output-column names in order lifecycle commands.
-- Forward-only replacement of existing functions; no table/schema/data reset.

create or replace function public.confirm_order(p_order_id uuid, p_idempotency_key text default null::text)
returns table(order_id uuid, order_number text, lifecycle_state text)
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
 v_state text;
 v_order_number text;
 v_original_amount numeric(12,2);
 v_customer_id uuid;
 v_item_count integer;
 v_hash text;
 v_is_new boolean;
 v_status text;
 v_result jsonb;
begin
 if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then
   raise exception using errcode='42501',message='Authenticated operational role required';
 end if;
 if p_order_id is null then raise exception using errcode='22023',message='Order ID is required'; end if;
 if btrim(coalesce(p_idempotency_key,''))='' then raise exception using errcode='22023',message='Idempotency key is required'; end if;
 v_hash:=md5(jsonb_build_object('order_id',p_order_id)::text);
 select is_new,status,result into v_is_new,v_status,v_result
 from public.claim_command_idempotency('confirm_order',btrim(p_idempotency_key),v_hash);
 if not v_is_new then
   return query select (v_result->>'order_id')::uuid,v_result->>'order_number',v_result->>'lifecycle_state';
   return;
 end if;
 select o.lifecycle_state,o.order_number,o.original_amount,o.customer_id
 into v_state,v_order_number,v_original_amount,v_customer_id
 from public.orders o where o.id=p_order_id for update;
 if not found then raise exception using errcode='P0002',message='Order not found'; end if;
 if v_state <> 'Draft' then raise exception using errcode='P0001',message='Only Draft orders can be confirmed'; end if;
 if v_customer_id is null then raise exception using errcode='P0001',message='Order must have a customer before confirmation'; end if;
 if v_original_amount is null or v_original_amount<0 then raise exception using errcode='P0001',message='Order Total Order Amount must be zero or greater'; end if;
 select count(*) into v_item_count from public.order_items oi where oi.order_id=p_order_id;
 if v_item_count=0 then raise exception using errcode='P0001',message='Order must contain at least one item'; end if;
 if exists(select 1 from public.order_items oi where oi.order_id=p_order_id and (btrim(coalesce(oi.description,''))='' or oi.quantity is null or oi.quantity<=0)) then
   raise exception using errcode='P0001',message='Order contains an invalid item';
 end if;
 update public.orders as o set lifecycle_state='Confirmed',updated_at=now() where o.id=p_order_id;
 insert into public.order_events(order_id,event_type,performed_by,metadata)
 values(p_order_id,'OrderConfirmed',auth.uid(),jsonb_build_object('from','Draft','to','Confirmed','original_amount',v_original_amount,'item_count',v_item_count));
 insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
 values(auth.uid(),'confirm_order','order',p_order_id,jsonb_build_object('lifecycle_state','Draft'),jsonb_build_object('lifecycle_state','Confirmed','original_amount',v_original_amount,'item_count',v_item_count));
 v_result:=jsonb_build_object('order_id',p_order_id,'order_number',v_order_number,'lifecycle_state','Confirmed');
 perform public.complete_command_idempotency('confirm_order',btrim(p_idempotency_key),v_result);
 return query select p_order_id,v_order_number,'Confirmed'::text;
end;
$function$;

create or replace function public.cancel_order(p_order_id uuid)
returns table(order_id uuid, order_number text, lifecycle_state text)
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
 v_state text;
 v_order_number text;
begin
 if auth.uid() is null or public.app_role() is null then
   raise exception using errcode='42501',message='Authentication required';
 end if;
 select o.lifecycle_state,o.order_number into v_state,v_order_number
 from public.orders o where o.id=p_order_id for update;
 if not found then raise exception using errcode='P0002',message='Order not found'; end if;
 if v_state not in ('Draft','Confirmed') then
   raise exception using errcode='P0001',message='Order cannot be cancelled after parcel dispatch or later';
 end if;
 if exists(select 1 from public.parcels p where p.order_id=p_order_id and p.state not in ('Prepared','Cancelled')) then
   raise exception using errcode='P0001',message='Order cannot be cancelled after a parcel reaches dispatch or later';
 end if;
 update public.orders as o set lifecycle_state='Cancelled',updated_at=now() where o.id=p_order_id;
 update public.parcel_items pi set allocation_state='Reversed',updated_at=now()
 from public.parcels p
 where p.id=pi.parcel_id and p.order_id=p_order_id and p.state='Prepared' and pi.allocation_state='Allocated';
 update public.parcels as p set state='Cancelled',updated_at=now() where p.order_id=p_order_id and p.state='Prepared';
 insert into public.order_events(order_id,event_type,performed_by,metadata)
 values(p_order_id,'OrderCancelled',auth.uid(),jsonb_build_object('from',v_state,'to','Cancelled','allocation_reversal','applied'));
 insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
 values(auth.uid(),'cancel_order','order',p_order_id,jsonb_build_object('lifecycle_state',v_state),jsonb_build_object('lifecycle_state','Cancelled'));
 return query select p_order_id,v_order_number,'Cancelled'::text;
end;
$function$;

revoke all on function public.confirm_order(uuid,text) from public, anon;
grant execute on function public.confirm_order(uuid,text) to authenticated;
revoke all on function public.cancel_order(uuid) from public, anon;
grant execute on function public.cancel_order(uuid) to authenticated;
