-- P15-T239 regression: preview_import_customer_changes must pass PL/pgSQL
-- static analysis after qualifying every import_rows column reference.

DO $$
DECLARE
  v_errors integer;
BEGIN
  SELECT count(*)
    INTO v_errors
  FROM plpgsql_check_function_tb(
    'public.preview_import_customer_changes(uuid,text)'::regprocedure
  )
  WHERE level = 'error';

  IF v_errors <> 0 THEN
    RAISE EXCEPTION
      'P15-T239 preview_import_customer_changes still has % plpgsql_check error(s)',
      v_errors;
  END IF;
END;
$$;

-- Explicitly guard the latent ambiguity: the function body must qualify
-- import_rows.batch_id rather than relying on an unqualified column name.
DO $$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.preview_import_customer_changes(uuid,text)'::regprocedure
  )
  INTO v_definition;

  IF position('WHERE ir.batch_id = p_batch_id' in v_definition) = 0 THEN
    RAISE EXCEPTION
      'P15-T239 regression: preview function does not contain qualified ir.batch_id predicate';
  END IF;
END;
$$;
