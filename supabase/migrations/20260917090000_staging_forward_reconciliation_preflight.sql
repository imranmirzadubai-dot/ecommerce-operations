-- Audit-only preflight for the staging-to-current-main reconciliation.
-- This migration is intentionally fail-closed and performs NO schema or data changes.
-- It documents executable checks that must pass before any forward DDL is considered.

DO $$
DECLARE
  v_invoice_count bigint;
  v_bad_customer bigint;
  v_bad_parcel_count bigint;
BEGIN
  SELECT count(*) INTO v_invoice_count FROM public.invoice_records;

  SELECT count(*) INTO v_bad_customer
  FROM public.invoice_records ir
  LEFT JOIN public.orders o ON o.id = ir.order_id
  LEFT JOIN public.customers c ON c.id = o.customer_id
  WHERE c.id IS NULL;

  SELECT count(*) INTO v_bad_parcel_count
  FROM public.invoice_records ir
  LEFT JOIN LATERAL (
    SELECT count(*)::int AS parcel_count
    FROM public.parcels p
    WHERE p.order_id = ir.order_id
  ) pc ON true
  WHERE pc.parcel_count <> 1;

  IF v_bad_customer > 0 OR v_bad_parcel_count > 0 THEN
    RAISE EXCEPTION 'Forward reconciliation blocked: invoice source compatibility violations (invoice_count %, missing_customer %, invalid_parcel_count %)',
      v_invoice_count, v_bad_customer, v_bad_parcel_count;
  END IF;

  RAISE NOTICE 'Forward reconciliation preflight passed: invoice_count %, missing_customer %, invalid_parcel_count %',
    v_invoice_count, v_bad_customer, v_bad_parcel_count;
END $$;
