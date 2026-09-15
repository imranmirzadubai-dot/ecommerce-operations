-- P9-T138: transactional shipper assignment.
-- Assigns an active shipper to a Prepared parcel without changing dispatch state.
-- The assignment is auditable and idempotent; dispatch remains a separate command.

create or replace function public.assign_parcel_shipper(
  p_parcel_id uuid,
  p_shipper_id uuid,
  p_idempotency_key text
)
returns table(parcel_id uuid,parcel_number text,shipper_id uuid,shipper_name text,state text)
language plpgsql security definer set search_path=pg_catalog, public
as $$
declare v_parcel_number text; v_order_id uuid; v_state text; v_shipper_name text; v_existing_shipper_id uuid; v_hash text; v_is_new boolean; v_status text; v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('operations','admin') then raise exception using errcode='42501',message='Operations or admin role required'; end if;
  if p_parcel_id is null then raise exception using errcode='22023',message='Parcel ID is required'; end if;
  if p_shipper_id is null then raise exception using errcode='22023',message='Shipper ID is required'; end if;
  if btrim(coalesce(p_idempotency_key,''))='' then raise exception using errcode='22023',message='Idempotency key is required'; end if;
  v_hash:=md5(jsonb_build_object('parcel_id',p_parcel_id,'shipper_id',p_shipper_id)::text);
  select is_new,status,result into v_is_new,v_status,v_result from public.claim_command_idempotency('assign_parcel_shipper',btrim(p_idempotency_key),v_hash);
  if not v_is_new then return query select (v_result->>'parcel_id')::uuid,v_result->>'parcel_number',(v_result->>'shipper_id')::uuid,v_result->>'shipper_name',v_result->>'state'; return; end if;
  select p.parcel_number,p.order_id,p.state,p.shipper_id into v_parcel_number,v_order_id,v_state,v_existing_shipper_id from public.parcels p where p.id=p_parcel_id for update;
  if not found then raise exception using errcode='P0002',message='Parcel not found'; end if;
  if v_state<>'Prepared' then raise exception using errcode='P0001',message='Shipper assignment is permitted only while parcel is Prepared'; end if;
  select s.name into v_shipper_name from public.shippers s where s.id=p_shipper_id and s.active=true;
  if not found then raise exception using errcode='P0002',message='Active shipper not found'; end if;
  if v_existing_shipper_id is not null and v_existing_shipper_id<>p_shipper_id then raise exception using errcode='P0001',message='A different shipper is already assigned to this Prepared parcel'; end if;
  update public.parcels set shipper_id=p_shipper_id,updated_at=now() where id=p_parcel_id;
  insert into public.order_events(order_id,parcel_id,event_type,performed_by,metadata) values(v_order_id,p_parcel_id,'ShipperAssigned',auth.uid(),jsonb_build_object('parcel_number',v_parcel_number,'shipper_id',p_shipper_id,'shipper_name',v_shipper_name,'state',v_state));
  insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data) values(auth.uid(),'assign_parcel_shipper','parcel',p_parcel_id,jsonb_build_object('shipper_id',v_existing_shipper_id),jsonb_build_object('shipper_id',p_shipper_id,'shipper_name',v_shipper_name));
  v_result:=jsonb_build_object('parcel_id',p_parcel_id,'parcel_number',v_parcel_number,'shipper_id',p_shipper_id,'shipper_name',v_shipper_name,'state',v_state);
  perform public.complete_command_idempotency('assign_parcel_shipper',btrim(p_idempotency_key),v_result);
  return query select p_parcel_id,v_parcel_number,p_shipper_id,v_shipper_name,v_state;
end; $$;

revoke execute on function public.assign_parcel_shipper(uuid,uuid,text) from anon;
revoke execute on function public.assign_parcel_shipper(uuid,uuid,text) from public;
grant execute on function public.assign_parcel_shipper(uuid,uuid,text) to authenticated;
