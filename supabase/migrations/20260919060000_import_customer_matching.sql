-- P12-T190: match staged historical-import rows to existing customers and classify exceptions.
-- Existing customers are matched only by exact normalized phone. Unmatched valid rows are
-- classified as Create for the later production-import milestone; invalid/missing phones are errors.

alter table public.import_rows
  add column if not exists matched_customer_id uuid references public.customers(id) on delete restrict;

alter table public.import_rows
  add column if not exists customer_match_status text;

alter table public.import_rows
  add column if not exists customer_match_method text;

alter table public.import_rows
  add column if not exists customer_match_error text;

create index if not exists idx_import_rows_matched_customer_id
  on public.import_rows(matched_customer_id);

create index if not exists idx_import_rows_customer_match_status
  on public.import_rows(customer_match_status);

create or replace function public.match_import_customers(
  p_batch_id uuid,
  p_phone_field text,
  p_idempotency_key text
)
returns table(batch_id uuid, row_count integer, matched_count integer, create_count integer, error_count integer)
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

  if btrim(coalesce(p_phone_field, '')) = '' then
    raise exception using errcode='22023', message='Phone field is required';
  end if;

  select status
    into v_status
  from public.import_batches
  where id = p_batch_id
    and initiated_by = v_actor_id
  for update;

  if not found then
    raise exception using errcode='42501', message='Import batch is not accessible';
  end if;

  if v_status not in ('Ready','Validating') then
    raise exception using errcode='55000', message='Import batch must be Ready or Validating before customer matching';
  end if;

  select * into v_claim
  from public.claim_command_idempotency(
    'match_import_customers',
    p_idempotency_key,
    md5(concat_ws('|', p_batch_id::text, btrim(p_phone_field)))
  );

  if not v_claim.is_new then
    return query
      select (v_claim.result->>'batch_id')::uuid,
             (v_claim.result->>'row_count')::integer,
             (v_claim.result->>'matched_count')::integer,
             (v_claim.result->>'create_count')::integer,
             (v_claim.result->>'error_count')::integer;
    return;
  end if;

  -- Customer matching is read-only against existing customers. No customer row is created or updated here.
  update public.import_rows r
  set matched_customer_id = c.id,
      customer_match_status = 'Matched',
      customer_match_method = 'normalized_phone_exact',
      customer_match_error = null
  from public.customers c
  where r.batch_id = p_batch_id
    and r.status = 'Valid'
    and r.normalized_data ? btrim(p_phone_field)
    and r.normalized_data ->> btrim(p_phone_field) is not null
    and c.normalized_phone = r.normalized_data ->> btrim(p_phone_field);

  update public.import_rows r
  set matched_customer_id = null,
      customer_match_status = 'Create',
      customer_match_method = 'normalized_phone_no_existing_customer',
      customer_match_error = null
  where r.batch_id = p_batch_id
    and r.status = 'Valid'
    and r.customer_match_status is distinct from 'Matched'
    and r.normalized_data ? btrim(p_phone_field)
    and (r.normalized_data ->> btrim(p_phone_field)) is not null
    and btrim(r.normalized_data ->> btrim(p_phone_field)) <> '';

  update public.import_rows r
  set matched_customer_id = null,
      customer_match_status = 'Exception',
      customer_match_method = 'invalid_or_missing_phone',
      customer_match_error = 'A valid normalized phone is required for customer matching',
      status = 'Error',
      error = coalesce(nullif(r.error, ''), 'A valid normalized phone is required for customer matching')
  where r.batch_id = p_batch_id
    and r.status <> 'Valid'
    and r.customer_match_status is null;

  update public.import_rows r
  set matched_customer_id = null,
      customer_match_status = 'Exception',
      customer_match_method = 'invalid_or_missing_phone',
      customer_match_error = 'A valid normalized phone is required for customer matching',
      status = 'Error',
      error = 'A valid normalized phone is required for customer matching'
  where r.batch_id = p_batch_id
    and r.status = 'Valid'
    and (
      not (r.normalized_data ? btrim(p_phone_field))
      or r.normalized_data -> btrim(p_phone_field) is null
      or btrim(coalesce(r.normalized_data ->> btrim(p_phone_field), '')) = ''
      or (r.normalized_data ->> btrim(p_phone_field)) !~ '^\\+[1-9][0-9]{6,14}$'
    );

  select count(*)::integer into v_row_count
  from public.import_rows where batch_id = p_batch_id;

  select count(*)::integer into v_matched_count
  from public.import_rows where batch_id = p_batch_id and customer_match_status = 'Matched';

  select count(*)::integer into v_create_count
  from public.import_rows where batch_id = p_batch_id and customer_match_status = 'Create';

  select count(*)::integer into v_error_count
  from public.import_rows where batch_id = p_batch_id and customer_match_status = 'Exception';

  update public.import_batches
  set status = case when v_error_count = 0 then 'Ready' else 'Validating' end
  where id = p_batch_id;

  v_result := jsonb_build_object(
    'batch_id', p_batch_id,
    'row_count', v_row_count,
    'matched_count', v_matched_count,
    'create_count', v_create_count,
    'error_count', v_error_count
  );

  perform public.complete_command_idempotency(
    'match_import_customers',
    p_idempotency_key,
    v_result
  );

  return query select p_batch_id, v_row_count, v_matched_count, v_create_count, v_error_count;
end;
$$;

revoke all on function public.match_import_customers(uuid, text, text) from public, anon;
grant execute on function public.match_import_customers(uuid, text, text) to authenticated;
