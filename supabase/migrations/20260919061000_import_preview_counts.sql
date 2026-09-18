-- P12-T191: preview staged customer import create/update/error counts.
-- This is read-only with respect to business/customer data and staged rows.
-- Matched rows are presented as updates; Create rows as creates; Error rows as errors.

create or replace function public.preview_import_customer_changes(
  p_batch_id uuid,
  p_idempotency_key text
)
returns table(
  batch_id uuid,
  row_count integer,
  create_count integer,
  update_count integer,
  error_count integer
)
language plpgsql
security definer
stable
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_status text;
  v_row_count integer;
  v_create_count integer;
  v_update_count integer;
  v_error_count integer;
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

  if v_status not in ('Mapping','Validating','Ready') then
    raise exception using errcode='55000', message='Import batch must be Mapping, Validating, or Ready before preview';
  end if;

  select * into v_claim
  from public.claim_command_idempotency(
    'preview_import_customer_changes',
    p_idempotency_key,
    md5(p_batch_id::text)
  );

  if not v_claim.is_new then
    return query
      select (v_claim.result->>'batch_id')::uuid,
             (v_claim.result->>'row_count')::integer,
             (v_claim.result->>'create_count')::integer,
             (v_claim.result->>'update_count')::integer,
             (v_claim.result->>'error_count')::integer;
    return;
  end if;

  select count(*)::integer into v_row_count
  from public.import_rows
  where batch_id = p_batch_id;

  select count(*)::integer into v_create_count
  from public.import_rows
  where batch_id = p_batch_id and status = 'Create';

  select count(*)::integer into v_update_count
  from public.import_rows
  where batch_id = p_batch_id and status = 'Matched';

  select count(*)::integer into v_error_count
  from public.import_rows
  where batch_id = p_batch_id and status in ('Error','Exception');

  v_result := jsonb_build_object(
    'batch_id', p_batch_id,
    'row_count', v_row_count,
    'create_count', v_create_count,
    'update_count', v_update_count,
    'error_count', v_error_count
  );

  perform public.complete_command_idempotency(
    'preview_import_customer_changes',
    p_idempotency_key,
    v_result
  );

  return query select p_batch_id, v_row_count, v_create_count, v_update_count, v_error_count;
end;
$$;

revoke all on function public.preview_import_customer_changes(uuid, text) from public, anon;
grant execute on function public.preview_import_customer_changes(uuid, text) to authenticated;
