-- P15-T239 final regression guards.
-- These cover the four latent PL/pgSQL ambiguity defects plus the two
-- runtime contract defects discovered by the rollback rehearsal.

DO $$
DECLARE
  v_errors integer;
  v_fn regprocedure;
BEGIN
  FOREACH v_fn IN ARRAY ARRAY[
    'public.stage_import_file(text,text,jsonb,text)'::regprocedure,
    'public.map_import_columns(uuid,jsonb,text)'::regprocedure,
    'public.validate_import_rows(uuid,jsonb,jsonb,jsonb,jsonb,text)'::regprocedure,
    'public.normalize_import_phone_fields(uuid,jsonb,text,text)'::regprocedure,
    'public.assign_import_source_identity(uuid,jsonb,text)'::regprocedure,
    'public.match_import_customers(uuid,text,text)'::regprocedure,
    'public.preview_import_customer_changes(uuid,text)'::regprocedure,
    'public.reconcile_import_staging(uuid,text)'::regprocedure,
    'public.reconcile_import_monetary_counts(uuid,text,integer,numeric,text)'::regprocedure,
    'public.import_historical_batch(uuid,jsonb,text)'::regprocedure
  ]
  LOOP
    SELECT count(*) INTO v_errors
    FROM plpgsql_check_function_tb(v_fn)
    WHERE level = 'error';

    IF v_errors <> 0 THEN
      RAISE EXCEPTION
        'P15-T239 final regression: % has % plpgsql_check error(s)',
        v_fn, v_errors;
    END IF;
  END LOOP;
END;
$$;

DO $$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.reconcile_import_staging(uuid,text)'::regprocedure
  )
  INTO v_definition;

  IF position(
    'jsonb_build_object(''staging_reconciliation'', v_result)'
    IN v_definition
  ) = 0 THEN
    RAISE EXCEPTION
      'P15-T239 regression: staging reconciliation is not stored under staging_reconciliation';
  END IF;
END;
$$;

DO $$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.import_historical_batch(uuid,jsonb,text)'::regprocedure
  )
  INTO v_definition;

  IF position(
    'values(v_customer_id, v_order_date, ''AED'', v_amount, ''Draft'''
    IN v_definition
  ) = 0
  OR position(
    'set lifecycle_state = ''Completed'''
    IN v_definition
  ) = 0 THEN
    RAISE EXCEPTION
      'P15-T239 regression: historical import does not add items while Draft before completing the order';
  END IF;
END;
$$;
