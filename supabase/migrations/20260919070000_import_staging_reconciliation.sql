-- P12-T192: reconcile staged customer-import classification and persist the
-- deterministic reconciliation summary on the import batch.
-- This does not create/update production customers and does not alter staged rows.

create or replace function public.reconcile_import_staging(
  p_batch_id uuid,
  p_idempotency_key text
)
returns table(
  batch_id uuid,
  row_count integer,
  matched_count integer,
  create_count integer,
  exception_count integer,
  unclassified_count integer,
  status_mismatch_count integer,
  reconciled boolean
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_status text;
  v_row_count integer;
  v_matched_count integer;
  v_create_count integer;
  v_exception_count integer;
  v_unclassified_count integer;
  v_status_mismatch_count integer;
  v_reconciled boolean;
  v_claim record;
  v_result jsonb;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null or public.app_role() is null then
    raise exception using errcode='42501', message='Authentication required';
  end if;

  if public.app_role() <> 'admin' then
    raise exception using errcode='42501', message='Admin role required';
  end if;

  if p_batch_id is null then
    raise exception using errcode='22023', message='Import batch is required';
  end if;

  select b.status into v_status
  from public.import_batches b
  where b.id = p_batch_id
    and b.initiated_by = v_actor_id;

  if not found then
    raise exception using errcode='42501', message='Import batch is not accessible';
  end if;

  if v_status not in ('Validating','Ready') then
    raise exception using errcode='55000', message='Import batch must be Validating or Ready before staging reconciliation';
  end if;

  select * into v_claim
  from public.claim_command_idempotency(
    'reconcile_import_staging',
    p_idempotency_key,
    md5(p_batch_id::text)
  );

  if not v_claim.is_new then
    return query
      select (v_claim.result->>'batch_id')::uuid,
             (v_claim.result->>'row_count')::integer,
             (v_claim.result->>'matched_count')::integer,
             (v_claim.result->>'create_count')::integer,
             (v_claim.result->>'exception_count')::integer,
             (v_claim.result->>'unclassified_count')::integer,
             (v_claim.result->>'status_mismatch_count')::integer,
             (v_claim.result->>'reconciled')::boolean;
    return;
  end if;

  select count(*)::integer into v_row_count
  from public.import_rows
  where batch_id = p_batch_id;

  select count(*)::integer into v_matched_count
  from public.import_rows
  where batch_id = p_batch_id
    and customer_match_status = 'Matched';

  select count(*)::integer into v_create_count
  from public.import_rows
  where batch_id = p_batch_id
    and customer_match_status = 'Create';

  select count(*)::integer into v_exception_count
  from public.import_rows
  where batch_id = p_batch_id
    and customer_match_status = 'Exception';

  select count(*)::integer into v_unclassified_count
  from public.import_rows
  where batch_id = p_batch_id
    and customer_match_status is distinct from 'Matched'
    and customer_match_status is distinct from 'Create'
    and customer_match_status is distinct from 'Exception';

  select count(*)::integer into v_status_mismatch_count
  from public.import_rows
  where batch_id = p_batch_id
    and (
      (customer_match_status in ('Matched','Create') and status <> 'Valid')
      or (customer_match_status = 'Exception' and status <> 'Error')
    );

  v_reconciled :=
    v_row_count = v_matched_count + v_create_count + v_exception_count
    and v_unclassified_count = 0
    and v_status_mismatch_count = 0;

  v_result := jsonb_build_object(
    'batch_id', p_batch_id,
    'row_count', v_row_count,
    'matched_count', v_matched_count,
    'create_count', v_create_count,
    'exception_count', v_exception_count,
    'unclassified_count', v_unclassified_count,
    'status_mismatch_count', v_status_mismatch_count,
    'reconciled', v_reconciled
  );

  update public.import_batches
  set reconciliation_summary = v_result
  where id = p_batch_id
    and initiated_by = v_actor_id;

  perform public.complete_command_idempotency(
    'reconcile_import_staging',
    p_idempotency_key,
    v_result
  );

  return query
    select p_batch_id,
           v_row_count,
           v_matched_count,
           v_create_count,
           v_exception_count,
           v_unclassified_count,
           v_status_mismatch_count,
           v_reconciled;
end;
$$;

revoke all on function public.reconcile_import_staging(uuid, text) from public, anon;
grant execute on function public.reconcile_import_staging(uuid, text) to authenticated;
