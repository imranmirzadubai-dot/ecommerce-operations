-- P17: qualify table columns that collide with RETURNS TABLE output names.
-- Forward-only, function-definition-only migration: no table/schema/data changes.
-- Preserve existing SECURITY DEFINER and fixed search_path contracts.

CREATE OR REPLACE FUNCTION public.allocate_cod_obligation_to_parcel(
  p_cod_obligation_id uuid,
  p_parcel_id uuid,
  p_expected_amount numeric,
  p_idempotency_key text
)
RETURNS TABLE(allocation_id uuid, cod_obligation_id uuid, parcel_id uuid, expected_amount numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_obligation public.cod_obligations%rowtype;
  v_parcel public.parcels%rowtype;
  v_allocation public.cod_obligation_allocations%rowtype;
  v_claim record;
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR public.app_role() NOT IN ('sales','operations','admin') THEN
    RAISE EXCEPTION USING errcode='42501', message='Authenticated operational role required';
  END IF;
  IF p_cod_obligation_id IS NULL OR p_parcel_id IS NULL THEN
    RAISE EXCEPTION USING errcode='22023', message='COD obligation ID and parcel ID are required';
  END IF;
  IF p_expected_amount IS NULL OR p_expected_amount < 0 OR p_expected_amount <> round(p_expected_amount, 2) THEN
    RAISE EXCEPTION USING errcode='22023', message='Expected COD amount must be non-negative and have at most two decimal places';
  END IF;
  IF btrim(coalesce(p_idempotency_key,''))='' THEN
    RAISE EXCEPTION USING errcode='22023', message='Idempotency key is required';
  END IF;

  v_claim := public.claim_command_idempotency(
    'allocate_cod_obligation_to_parcel', p_idempotency_key,
    md5(concat_ws('|', p_cod_obligation_id::text, p_parcel_id::text, p_expected_amount::text))
  );
  IF NOT v_claim.is_new THEN
    RETURN QUERY SELECT
      (v_claim.result->>'allocation_id')::uuid,
      (v_claim.result->>'cod_obligation_id')::uuid,
      (v_claim.result->>'parcel_id')::uuid,
      (v_claim.result->>'expected_amount')::numeric(12,2);
    RETURN;
  END IF;

  SELECT co.* INTO v_obligation
  FROM public.cod_obligations AS co
  WHERE co.id = p_cod_obligation_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002', message='COD obligation not found'; END IF;
  IF v_obligation.state IN ('Voided','Closed') THEN
    RAISE EXCEPTION USING errcode='P0001', message='COD obligation is not eligible for parcel allocation';
  END IF;

  SELECT p.* INTO v_parcel
  FROM public.parcels AS p
  WHERE p.id = p_parcel_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002', message='Parcel not found'; END IF;
  IF v_parcel.order_id <> v_obligation.order_id THEN
    RAISE EXCEPTION USING errcode='P0001', message='Parcel does not belong to the COD obligation order';
  END IF;
  IF v_parcel.state = 'Cancelled' THEN
    RAISE EXCEPTION USING errcode='P0001', message='Cancelled parcel is not eligible for COD allocation';
  END IF;

  SELECT coa.* INTO v_allocation
  FROM public.cod_obligation_allocations AS coa
  WHERE coa.cod_obligation_id = p_cod_obligation_id
    AND coa.parcel_id = p_parcel_id
  FOR UPDATE;
  IF FOUND THEN
    IF v_allocation.expected_amount <> p_expected_amount THEN
      RAISE EXCEPTION USING errcode='23505', message='COD allocation already exists for this obligation and parcel with a different amount';
    END IF;
  ELSE
    INSERT INTO public.cod_obligation_allocations(cod_obligation_id, parcel_id, expected_amount)
    VALUES (p_cod_obligation_id, p_parcel_id, p_expected_amount)
    RETURNING * INTO v_allocation;
  END IF;

  v_result := jsonb_build_object(
    'allocation_id', v_allocation.id, 'cod_obligation_id', v_allocation.cod_obligation_id,
    'parcel_id', v_allocation.parcel_id, 'expected_amount', v_allocation.expected_amount
  );
  INSERT INTO public.order_events(order_id, parcel_id, event_type, performed_by, metadata)
  VALUES (v_obligation.order_id, p_parcel_id, 'CodObligationAllocatedToParcel', auth.uid(),
    jsonb_build_object('cod_obligation_id', p_cod_obligation_id, 'allocation_id', v_allocation.id,
      'expected_amount', v_allocation.expected_amount));
  INSERT INTO public.audit_logs(actor, action, entity_type, entity_id, after_data)
  VALUES (auth.uid(), 'allocate_cod_obligation_to_parcel', 'cod_obligation_allocation', v_allocation.id, v_result);
  PERFORM public.complete_command_idempotency('allocate_cod_obligation_to_parcel', p_idempotency_key, v_result);
  RETURN QUERY SELECT v_allocation.id, v_allocation.cod_obligation_id, v_allocation.parcel_id, v_allocation.expected_amount;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_parcel(p_parcel_id uuid, p_idempotency_key text)
RETURNS TABLE(parcel_id uuid, parcel_number text, state text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_order_id uuid;
  v_order_number text;
  v_state text;
  v_parcel_number text;
  v_hash text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR public.app_role() IS NULL THEN
    RAISE EXCEPTION USING errcode='42501',message='Authentication required';
  END IF;
  IF p_idempotency_key IS NULL OR btrim(p_idempotency_key)='' THEN
    RAISE EXCEPTION USING errcode='22023',message='Idempotency key is required';
  END IF;
  v_hash := md5(jsonb_build_object('parcel_id',p_parcel_id)::text);
  SELECT c.is_new,c.status,c.result INTO v_is_new,v_status,v_result
  FROM public.claim_command_idempotency('cancel_parcel',btrim(p_idempotency_key),v_hash) AS c;
  IF NOT v_is_new THEN
    RETURN QUERY SELECT (v_result->>'parcel_id')::uuid, v_result->>'parcel_number', v_result->>'state';
    RETURN;
  END IF;
  SELECT p.order_id,p.parcel_number,p.state,o.order_number
    INTO v_order_id,v_parcel_number,v_state,v_order_number
  FROM public.parcels AS p
  JOIN public.orders AS o ON o.id=p.order_id
  WHERE p.id=p_parcel_id
  FOR UPDATE OF p;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002',message='Parcel not found'; END IF;
  IF v_state<>'Prepared' THEN
    RAISE EXCEPTION USING errcode='P0001',message='Only Prepared parcels can be cancelled';
  END IF;

  UPDATE public.parcel_items AS pi
     SET allocation_state='Reversed',updated_at=now()
   WHERE pi.parcel_id=p_parcel_id
     AND pi.allocation_state='Allocated';
  UPDATE public.parcels AS p SET state='Cancelled',updated_at=now() WHERE p.id=p_parcel_id;
  INSERT INTO public.order_events(order_id,parcel_id,event_type,performed_by,metadata)
  VALUES (v_order_id,p_parcel_id,'ParcelCancelled',auth.uid(),
    jsonb_build_object('from','Prepared','to','Cancelled','order_number',v_order_number,'allocation_reversal','applied'));
  INSERT INTO public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
  VALUES (auth.uid(),'cancel_parcel','parcel',p_parcel_id,
    jsonb_build_object('state','Prepared'),jsonb_build_object('state','Cancelled','order_id',v_order_id));
  v_result := jsonb_build_object('parcel_id',p_parcel_id,'parcel_number',v_parcel_number,'state','Cancelled');
  PERFORM public.complete_command_idempotency('cancel_parcel',btrim(p_idempotency_key),v_result);
  RETURN QUERY SELECT p_parcel_id,v_parcel_number,'Cancelled'::text;
END;
$function$;

CREATE OR REPLACE FUNCTION public.map_import_columns(p_batch_id uuid, p_mapping jsonb, p_idempotency_key text)
RETURNS TABLE(batch_id uuid, row_count integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_actor_id uuid;
  v_status text;
  v_row_count integer;
  v_claim record;
  v_result jsonb;
  v_source_column text;
  v_target_column text;
  v_target_count integer;
  v_mapping_count integer;
BEGIN
  v_actor_id := auth.uid();
  IF v_actor_id IS NULL OR public.app_role() IS NULL THEN
    RAISE EXCEPTION USING errcode='42501',message='Authentication required';
  END IF;
  IF public.app_role()<>'admin' THEN RAISE EXCEPTION USING errcode='42501',message='Admin role required'; END IF;
  IF p_batch_id IS NULL THEN RAISE EXCEPTION USING errcode='22023',message='Import batch is required'; END IF;
  IF jsonb_typeof(p_mapping)<>'object' THEN RAISE EXCEPTION USING errcode='22023',message='Column mapping must be a JSON object'; END IF;
  IF jsonb_object_length(p_mapping)=0 THEN RAISE EXCEPTION USING errcode='22023',message='Column mapping must not be empty'; END IF;
  FOR v_source_column,v_target_column IN SELECT e.key,e.value FROM jsonb_each_text(p_mapping) AS e LOOP
    IF btrim(v_source_column)='' OR btrim(v_target_column)='' THEN
      RAISE EXCEPTION USING errcode='22023',message='Column mapping names must not be empty';
    END IF;
  END LOOP;
  SELECT count(*)::integer,count(DISTINCT btrim(e.value))::integer
    INTO v_mapping_count,v_target_count FROM jsonb_each_text(p_mapping) AS e;
  IF v_mapping_count<>v_target_count THEN
    RAISE EXCEPTION USING errcode='22023',message='Column mapping target names must be unique';
  END IF;
  SELECT ib.status INTO v_status FROM public.import_batches AS ib
  WHERE ib.id=p_batch_id AND ib.initiated_by=v_actor_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='42501',message='Import batch is not accessible'; END IF;
  IF v_status<>'Uploaded' THEN RAISE EXCEPTION USING errcode='55000',message='Import batch must be Uploaded before mapping'; END IF;
  SELECT * INTO v_claim FROM public.claim_command_idempotency(
    'map_import_columns',p_idempotency_key,md5(concat_ws('|',p_batch_id::text,p_mapping::text)));
  IF NOT v_claim.is_new THEN
    RETURN QUERY SELECT (v_claim.result->>'batch_id')::uuid,(v_claim.result->>'row_count')::integer;
    RETURN;
  END IF;

  UPDATE public.import_rows AS r
     SET normalized_data=mapped.normalized_data,status='Pending'
    FROM (
      SELECT r2.id,
        coalesce(jsonb_object_agg(btrim(m.value),r2.raw_data->m.key)
          FILTER (WHERE r2.raw_data ? m.key),'{}'::jsonb) AS normalized_data
      FROM public.import_rows AS r2
      CROSS JOIN LATERAL jsonb_each_text(p_mapping) AS m
      WHERE r2.batch_id=p_batch_id AND jsonb_typeof(r2.raw_data)='object'
      GROUP BY r2.id
    ) AS mapped
   WHERE r.id=mapped.id;
  SELECT count(*)::integer INTO v_row_count
  FROM public.import_rows AS ir WHERE ir.batch_id=p_batch_id;
  UPDATE public.import_batches AS ib SET status='Mapping' WHERE ib.id=p_batch_id;
  v_result := jsonb_build_object('batch_id',p_batch_id,'row_count',v_row_count);
  PERFORM public.complete_command_idempotency('map_import_columns',p_idempotency_key,v_result);
  RETURN QUERY SELECT p_batch_id,v_row_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.stage_import_file(p_source_system text, p_source_file text, p_rows jsonb, p_idempotency_key text)
RETURNS TABLE(batch_id uuid, row_count integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_actor_id uuid;
  v_batch_id uuid;
  v_row_count integer;
  v_claim record;
  v_result jsonb;
BEGIN
  v_actor_id := auth.uid();
  IF v_actor_id IS NULL OR public.app_role() IS NULL THEN
    RAISE EXCEPTION USING errcode='42501',message='Authentication required';
  END IF;
  IF public.app_role()<>'admin' THEN RAISE EXCEPTION USING errcode='42501',message='Admin role required'; END IF;
  IF btrim(coalesce(p_source_system,''))='' THEN RAISE EXCEPTION USING errcode='22023',message='Source system is required'; END IF;
  IF btrim(coalesce(p_source_file,''))='' THEN RAISE EXCEPTION USING errcode='22023',message='Source file is required'; END IF;
  IF jsonb_typeof(p_rows)<>'array' THEN RAISE EXCEPTION USING errcode='22023',message='Import rows must be a JSON array'; END IF;
  IF jsonb_array_length(p_rows)=0 THEN RAISE EXCEPTION USING errcode='22023',message='Import rows must not be empty'; END IF;
  SELECT * INTO v_claim FROM public.claim_command_idempotency(
    'stage_import_file',p_idempotency_key,
    md5(concat_ws('|',btrim(p_source_system),btrim(p_source_file),p_rows::text)));
  IF NOT v_claim.is_new THEN
    RETURN QUERY SELECT (v_claim.result->>'batch_id')::uuid,(v_claim.result->>'row_count')::integer;
    RETURN;
  END IF;
  INSERT INTO public.import_batches(source_system,source_file,initiated_by,status)
  VALUES (btrim(p_source_system),btrim(p_source_file),v_actor_id,'Uploaded') RETURNING id INTO v_batch_id;
  INSERT INTO public.import_rows(batch_id,source_row_number,source_record_id,raw_data,status)
  SELECT v_batch_id,j.ordinality::integer,nullif(btrim(j.elem->>'source_record_id'),''),j.elem,'Pending'
  FROM jsonb_array_elements(p_rows) WITH ORDINALITY AS j(elem,ordinality)
  WHERE jsonb_typeof(j.elem)='object';
  SELECT count(*)::integer INTO v_row_count FROM public.import_rows AS ir WHERE ir.batch_id=v_batch_id;
  IF v_row_count<>jsonb_array_length(p_rows) THEN
    RAISE EXCEPTION USING errcode='22023',message='Every import row must be a JSON object';
  END IF;
  v_result := jsonb_build_object('batch_id',v_batch_id,'row_count',v_row_count);
  PERFORM public.complete_command_idempotency('stage_import_file',p_idempotency_key,v_result);
  RETURN QUERY SELECT v_batch_id,v_row_count;
END;
$function$;
