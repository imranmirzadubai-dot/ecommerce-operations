-- P15-T239: eliminate RETURNS TABLE output-column ambiguity in preview runtime.
-- The output column batch_id is an implicit PL/pgSQL variable, so all
-- table-column references are explicitly qualified.

CREATE OR REPLACE FUNCTION public.preview_import_customer_changes(
  p_batch_id uuid,
  p_idempotency_key text
)
RETURNS TABLE(
  batch_id uuid,
  row_count integer,
  create_count integer,
  update_count integer,
  error_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_actor_id uuid;
  v_status text;
  v_row_count integer;
  v_create_count integer;
  v_update_count integer;
  v_error_count integer;
  v_claim record;
  v_result jsonb;
BEGIN
  v_actor_id := auth.uid();

  IF v_actor_id IS NULL OR public.app_role() IS NULL THEN
    RAISE EXCEPTION USING errcode='42501', message='Authentication required';
  END IF;

  IF public.app_role() <> 'admin' THEN
    RAISE EXCEPTION USING errcode='42501', message='Admin role required';
  END IF;

  IF p_batch_id IS NULL THEN
    RAISE EXCEPTION USING errcode='22023', message='Import batch is required';
  END IF;

  SELECT b.status INTO v_status
  FROM public.import_batches b
  WHERE b.id = p_batch_id
    AND b.initiated_by = v_actor_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='42501', message='Import batch is not accessible';
  END IF;

  IF v_status NOT IN ('Mapping','Validating','Ready') THEN
    RAISE EXCEPTION USING errcode='55000', message='Import batch must be Mapping, Validating, or Ready before preview';
  END IF;

  SELECT * INTO v_claim
  FROM public.claim_command_idempotency(
    'preview_import_customer_changes',
    p_idempotency_key,
    md5(p_batch_id::text)
  );

  IF NOT v_claim.is_new THEN
    RETURN QUERY
      SELECT (v_claim.result->>'batch_id')::uuid,
             (v_claim.result->>'row_count')::integer,
             (v_claim.result->>'create_count')::integer,
             (v_claim.result->>'update_count')::integer,
             (v_claim.result->>'error_count')::integer;
    RETURN;
  END IF;

  SELECT count(*)::integer,
         count(*) FILTER (WHERE ir.customer_match_status = 'Create')::integer,
         count(*) FILTER (WHERE ir.customer_match_status = 'Matched')::integer,
         count(*) FILTER (
           WHERE ir.status = 'Invalid'
              OR ir.customer_match_status = 'Exception'
         )::integer
    INTO v_row_count, v_create_count, v_update_count, v_error_count
  FROM public.import_rows ir
  WHERE ir.batch_id = p_batch_id;

  v_result := jsonb_build_object(
    'batch_id', p_batch_id,
    'row_count', v_row_count,
    'create_count', v_create_count,
    'update_count', v_update_count,
    'error_count', v_error_count
  );

  PERFORM public.complete_command_idempotency(
    'preview_import_customer_changes',
    p_idempotency_key,
    v_result
  );

  RETURN QUERY
    SELECT p_batch_id, v_row_count, v_create_count, v_update_count, v_error_count;
END;
$function$;
