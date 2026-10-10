-- P17: qualify table columns that collide with returns table output names.
-- Forward-only, function-definition-only migration: no table/schema/data changes.
-- Preserve existing security definer and fixed search_path contracts.

create or replace function public.allocate_cod_obligation_to_parcel(
  p_cod_obligation_id uuid,
  p_parcel_id uuid,
  p_expected_amount numeric,
  p_idempotency_key text
)
returns table(allocation_id uuid, cod_obligation_id uuid, parcel_id uuid, expected_amount numeric)
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_obligation public.cod_obligations%rowtype;
  v_parcel public.parcels%rowtype;
  v_allocation public.cod_obligation_allocations%rowtype;
  v_claim record;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then
    raise exception using errcode='42501', message='Authenticated operational role required';
  end if;
  if p_cod_obligation_id is null or p_parcel_id is null then
    raise exception using errcode='22023', message='COD obligation ID and parcel ID are required';
  end if;
  if p_expected_amount is null or p_expected_amount < 0 or p_expected_amount <> round(p_expected_amount, 2) then
    raise exception using errcode='22023', message='Expected COD amount must be non-negative and have at most two decimal places';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;

  v_claim := public.claim_command_idempotency(
    'allocate_cod_obligation_to_parcel', p_idempotency_key,
    md5(concat_ws('|', p_cod_obligation_id::text, p_parcel_id::text, p_expected_amount::text))
  );
  if not v_claim.is_new then
    return query select
      (v_claim.result->>'allocation_id')::uuid,
      (v_claim.result->>'cod_obligation_id')::uuid,
      (v_claim.result->>'parcel_id')::uuid,
      (v_claim.result->>'expected_amount')::numeric(12,2);
    return;
  end if;

  select co.* into v_obligation
  from public.cod_obligations as co
  where co.id = p_cod_obligation_id
  for update;
  if not FOUND then raise exception using errcode='P0002', message='COD obligation not found'; end if;
  if v_obligation.state in ('Voided','Closed') then
    raise exception using errcode='P0001', message='COD obligation is not eligible for parcel allocation';
  end if;

  select p.* into v_parcel
  from public.parcels as p
  where p.id = p_parcel_id
  for update;
  if not FOUND then raise exception using errcode='P0002', message='Parcel not found'; end if;
  if v_parcel.order_id <> v_obligation.order_id then
    raise exception using errcode='P0001', message='Parcel does not belong to the COD obligation order';
  end if;
  if v_parcel.state = 'Cancelled' then
    raise exception using errcode='P0001', message='Cancelled parcel is not eligible for COD allocation';
  end if;

  select coa.* into v_allocation
  from public.cod_obligation_allocations as coa
  where coa.cod_obligation_id = p_cod_obligation_id
    and coa.parcel_id = p_parcel_id
  for update;
  if FOUND then
    if v_allocation.expected_amount <> p_expected_amount then
      raise exception using errcode='23505', message='COD allocation already exists for this obligation and parcel with a different amount';
    end if;
  ELSE
    insert into public.cod_obligation_allocations(cod_obligation_id, parcel_id, expected_amount)
    values (p_cod_obligation_id, p_parcel_id, p_expected_amount)
    returning * into v_allocation;
  end if;

  v_result := jsonb_build_object(
    'allocation_id', v_allocation.id, 'cod_obligation_id', v_allocation.cod_obligation_id,
    'parcel_id', v_allocation.parcel_id, 'expected_amount', v_allocation.expected_amount
  );
  insert into public.order_events(order_id, parcel_id, event_type, performed_by, metadata)
  values (v_obligation.order_id, p_parcel_id, 'CodObligationAllocatedToParcel', auth.uid(),
    jsonb_build_object('cod_obligation_id', p_cod_obligation_id, 'allocation_id', v_allocation.id,
      'expected_amount', v_allocation.expected_amount));
  insert into public.audit_logs(actor, action, entity_type, entity_id, after_data)
  values (auth.uid(), 'allocate_cod_obligation_to_parcel', 'cod_obligation_allocation', v_allocation.id, v_result);
  perform public.complete_command_idempotency('allocate_cod_obligation_to_parcel', p_idempotency_key, v_result);
  return query select v_allocation.id, v_allocation.cod_obligation_id, v_allocation.parcel_id, v_allocation.expected_amount;
end;
$function$;

create or replace function public.cancel_parcel(p_parcel_id uuid, p_idempotency_key text)
returns table(parcel_id uuid, parcel_number text, state text)
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_order_id uuid;
  v_order_number text;
  v_state text;
  v_parcel_number text;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
begin
  if auth.uid() is null or public.app_role() not in ('sales','operations','admin') then
    raise exception using errcode='42501',message='Authenticated operational role required';
  end if;
  if p_idempotency_key is null or btrim(p_idempotency_key)='' then
    raise exception using errcode='22023',message='Idempotency key is required';
  end if;
  v_hash := md5(jsonb_build_object('parcel_id',p_parcel_id)::text);
  select c.is_new,c.status,c.result into v_is_new,v_status,v_result
  from public.claim_command_idempotency('cancel_parcel',btrim(p_idempotency_key),v_hash) as c;
  if not v_is_new then
    return query select (v_result->>'parcel_id')::uuid, v_result->>'parcel_number', v_result->>'state';
    return;
  end if;
  select p.order_id,p.parcel_number,p.state,o.order_number
    into v_order_id,v_parcel_number,v_state,v_order_number
  from public.parcels as p
  join public.orders as o on o.id=p.order_id
  where p.id=p_parcel_id
  for update of p;
  if not FOUND then raise exception using errcode='P0002',message='Parcel not found'; end if;
  if v_state<>'Prepared' then
    raise exception using errcode='P0001',message='Only Prepared parcels can be cancelled';
  end if;

  update public.parcel_items as pi
     SET allocation_state='Reversed',updated_at=now()
   where pi.parcel_id = p_parcel_id
     and pi.allocation_state = 'Allocated';
  update public.parcels as p SET state='Cancelled',updated_at=now() where p.id=p_parcel_id;
  insert into public.order_events(order_id,parcel_id,event_type,performed_by,metadata)
  values (v_order_id,p_parcel_id,'ParcelCancelled',auth.uid(),
    jsonb_build_object('from','Prepared','to','Cancelled','order_number',v_order_number,'allocation_reversal','applied'));
  insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
  values (auth.uid(),'cancel_parcel','parcel',p_parcel_id,
    jsonb_build_object('state','Prepared'),jsonb_build_object('state','Cancelled','order_id',v_order_id));
  v_result := jsonb_build_object('parcel_id',p_parcel_id,'parcel_number',v_parcel_number,'state','Cancelled');
  perform public.complete_command_idempotency('cancel_parcel',btrim(p_idempotency_key),v_result);
  return query select p_parcel_id,v_parcel_number,'Cancelled'::text;
end;
$function$;

create or replace function public.map_import_columns(p_batch_id uuid, p_mapping jsonb, p_idempotency_key text)
returns table(batch_id uuid, row_count integer)
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_actor_id uuid;
  v_status text;
  v_row_count integer;
  v_claim record;
  v_result jsonb;
  v_source_column text;
  v_target_column text;
  v_target_count integer;
  v_mapping_count integer;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null or public.app_role() is null then
    raise exception using errcode='42501',message='Authentication required';
  end if;
  if public.app_role()<>'admin' then raise exception using errcode='42501',message='Admin role required'; end if;
  if p_batch_id is null then raise exception using errcode='22023',message='Import batch is required'; end if;
  if jsonb_typeof(p_mapping)<>'object' then raise exception using errcode='22023',message='Column mapping must be a JSON object'; end if;
  if jsonb_object_length(p_mapping)=0 then raise exception using errcode='22023',message='Column mapping must not be empty'; end if;
  FOR v_source_column,v_target_column in select e.key,e.value from jsonb_each_text(p_mapping) as e LOOP
    if btrim(v_source_column)='' or btrim(v_target_column)='' then
      raise exception using errcode='22023',message='Column mapping names must not be empty';
    end if;
  end LOOP;
  select count(*)::integer,count(DISTINCT btrim(e.value))::integer
    into v_mapping_count,v_target_count from jsonb_each_text(p_mapping) as e;
  if v_mapping_count<>v_target_count then
    raise exception using errcode='22023',message='Column mapping target names must be unique';
  end if;
  select ib.status into v_status from public.import_batches as ib
  where ib.id=p_batch_id and ib.initiated_by=v_actor_id for update;
  if not FOUND then raise exception using errcode='42501',message='Import batch is not accessible'; end if;
  if v_status<>'Uploaded' then raise exception using errcode='55000',message='Import batch must be Uploaded before mapping'; end if;
  select * into v_claim from public.claim_command_idempotency(
    'map_import_columns',p_idempotency_key,md5(concat_ws('|',p_batch_id::text,p_mapping::text)));
  if not v_claim.is_new then
    return query select (v_claim.result->>'batch_id')::uuid,(v_claim.result->>'row_count')::integer;
    return;
  end if;

  update public.import_rows as r
     SET normalized_data=mapped.normalized_data,status='Pending'
    from (
      select r2.id,
        coalesce(jsonb_object_agg(btrim(m.value),r2.raw_data->m.key)
          filter (where r2.raw_data ? m.key),'{}'::jsonb) as normalized_data
      from public.import_rows as r2
      cross join lateral jsonb_each_text(p_mapping) as m
      where r2.batch_id=p_batch_id and jsonb_typeof(r2.raw_data)='object'
      group by r2.id
    ) as mapped
   where r.id=mapped.id;
  select count(*)::integer into v_row_count
  from public.import_rows ir where ir.batch_id = p_batch_id;
  update public.import_batches as ib SET status='Mapping' where ib.id=p_batch_id;
  v_result := jsonb_build_object('batch_id',p_batch_id,'row_count',v_row_count);
  perform public.complete_command_idempotency('map_import_columns',p_idempotency_key,v_result);
  return query select p_batch_id,v_row_count;
end;
$function$;

create or replace function public.stage_import_file(p_source_system text, p_source_file text, p_rows jsonb, p_idempotency_key text)
returns table(batch_id uuid, row_count integer)
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_actor_id uuid;
  v_batch_id uuid;
  v_row_count integer;
  v_claim record;
  v_result jsonb;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null or public.app_role() is null then
    raise exception using errcode='42501',message='Authentication required';
  end if;
  if public.app_role()<>'admin' then raise exception using errcode='42501',message='Admin role required'; end if;
  if btrim(coalesce(p_source_system,''))='' then raise exception using errcode='22023',message='Source system is required'; end if;
  if btrim(coalesce(p_source_file,''))='' then raise exception using errcode='22023',message='Source file is required'; end if;
  if jsonb_typeof(p_rows)<>'array' then raise exception using errcode='22023',message='Import rows must be a JSON array'; end if;
  if jsonb_array_length(p_rows)=0 then raise exception using errcode='22023',message='Import rows must not be empty'; end if;
  select * into v_claim from public.claim_command_idempotency(
    'stage_import_file',p_idempotency_key,
    md5(concat_ws('|',btrim(p_source_system),btrim(p_source_file),p_rows::text)));
  if not v_claim.is_new then
    return query select (v_claim.result->>'batch_id')::uuid,(v_claim.result->>'row_count')::integer;
    return;
  end if;
  insert into public.import_batches(source_system,source_file,initiated_by,status)
  values (btrim(p_source_system),btrim(p_source_file),v_actor_id,'Uploaded') returning id into v_batch_id;
  insert into public.import_rows(batch_id,source_row_number,source_record_id,raw_data,status)
  select v_batch_id,j.ordinality::integer,nullif(btrim(j.elem->>'source_record_id'),''),j.elem,'Pending'
  from jsonb_array_elements(p_rows) with ordinality as j(elem,ordinality)
  where jsonb_typeof(j.elem)='object';
  select count(*)::integer into v_row_count from public.import_rows ir where ir.batch_id = v_batch_id;
  if v_row_count<>jsonb_array_length(p_rows) then
    raise exception using errcode='22023',message='Every import row must be a JSON object';
  end if;
  v_result := jsonb_build_object('batch_id',v_batch_id,'row_count',v_row_count);
  perform public.complete_command_idempotency('stage_import_file',p_idempotency_key,v_result);
  return query select v_batch_id,v_row_count;
end;
$function$;
