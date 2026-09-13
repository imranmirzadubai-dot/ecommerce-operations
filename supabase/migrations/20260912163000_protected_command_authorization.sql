begin;

-- P4-T084: make command-level authorization explicit for every protected
-- operational command. All three approved roles may use cancellation commands;
-- later role-specific tasks verify the complete matrix.

create or replace function public.cancel_order(p_order_id uuid,p_idempotency_key text)
returns table(order_id uuid,order_number text,lifecycle_state text)
language plpgsql security definer set search_path=pg_catalog, public
as $$
declare v_state text; v_order_number text; v_hash text; v_is_new boolean; v_status text; v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then raise exception using errcode='42501',message='Authenticated operational role required'; end if;
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

revoke all on function public.cancel_order(uuid,text) from public, anon;
grant execute on function public.cancel_order(uuid,text) to authenticated;

create or replace function public.cancel_parcel(p_parcel_id uuid,p_idempotency_key text)
returns table(parcel_id uuid,parcel_number text,state text)
language plpgsql security definer set search_path=pg_catalog, public
as $$
declare
  v_order_id uuid; v_order_number text; v_state text; v_parcel_number text;
  v_hash text; v_is_new boolean; v_status text; v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then raise exception using errcode='42501',message='Authenticated operational role required'; end if;
  if p_idempotency_key is null or btrim(p_idempotency_key)='' then raise exception using errcode='22023',message='Idempotency key is required'; end if;
  v_hash:=md5(jsonb_build_object('parcel_id',p_parcel_id)::text);
  select is_new,status,result into v_is_new,v_status,v_result from public.claim_command_idempotency('cancel_parcel',btrim(p_idempotency_key),v_hash);
  if not v_is_new then return query select (v_result->>'parcel_id')::uuid,v_result->>'parcel_number',v_result->>'state'; return; end if;
  select p.order_id,p.parcel_number,p.state,o.order_number into v_order_id,v_parcel_number,v_state,v_order_number
  from public.parcels p join public.orders o on o.id=p.order_id where p.id=p_parcel_id for update of p;
  if not found then raise exception using errcode='P0002',message='Parcel not found'; end if;
  if v_state<>'Prepared' then raise exception using errcode='P0001',message='Only Prepared parcels can be cancelled'; end if;
  update public.parcel_items set allocation_state='Reversed',updated_at=now() where parcel_id=p_parcel_id and allocation_state='Allocated';
  update public.parcels set state='Cancelled',updated_at=now() where id=p_parcel_id;
  insert into public.order_events(order_id,parcel_id,event_type,performed_by,metadata) values(v_order_id,p_parcel_id,'ParcelCancelled',auth.uid(),jsonb_build_object('from','Prepared','to','Cancelled','order_number',v_order_number,'allocation_reversal','applied'));
  insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data) values(auth.uid(),'cancel_parcel','parcel',p_parcel_id,jsonb_build_object('state','Prepared'),jsonb_build_object('state','Cancelled','order_id',v_order_id));
  v_result:=jsonb_build_object('parcel_id',p_parcel_id,'parcel_number',v_parcel_number,'state','Cancelled');
  perform public.complete_command_idempotency('cancel_parcel',btrim(p_idempotency_key),v_result);
  return query select p_parcel_id,v_parcel_number,'Cancelled'::text;
end; $$;

revoke all on function public.cancel_parcel(uuid,text) from public, anon;
grant execute on function public.cancel_parcel(uuid,text) to authenticated;

commit;
