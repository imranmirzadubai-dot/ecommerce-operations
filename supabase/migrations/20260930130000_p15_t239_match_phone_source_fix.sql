create or replace function public.match_import_customers(
  p_batch_id uuid,
  p_phone_field text,
  p_idempotency_key text
)
returns table(batch_id uuid, row_count integer, matched_count integer, create_count integer, error_count integer)
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_row_count integer := 0;
  v_matched_count integer := 0;
  v_create_count integer := 0;
  v_error_count integer := 0;
begin
  if p_batch_id is null then
    raise exception 'p_batch_id is required';
  end if;

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'p_idempotency_key is required';
  end if;

  update public.import_rows r
  set matched_customer_id = c.id,
      customer_match_status = 'Matched',
      customer_match_method = 'normalized_phone_exact',
      customer_match_error = null
  from public.customers c
  where r.batch_id = p_batch_id
    and nullif(btrim(r.normalized_data ->> p_phone_field), '') is not null
    and c.normalized_phone = nullif(btrim(r.normalized_data ->> p_phone_field), '')
    and r.customer_match_status is distinct from 'Matched';

  update public.import_rows r
  set customer_match_status = 'Create',
      customer_match_method = 'no_exact_normalized_phone_match',
      customer_match_error = null
  where r.batch_id = p_batch_id
    and r.customer_match_status is distinct from 'Matched';

  select count(*)::integer into v_row_count
  from public.import_rows ir where ir.batch_id = p_batch_id;

  select count(*)::integer into v_matched_count
  from public.import_rows ir where ir.batch_id = p_batch_id and ir.customer_match_status = 'Matched';

  select count(*)::integer into v_create_count
  from public.import_rows ir where ir.batch_id = p_batch_id and ir.customer_match_status = 'Create';

  select count(*)::integer into v_error_count
  from public.import_rows ir where ir.batch_id = p_batch_id and ir.customer_match_status = 'Exception';

  update public.import_batches
  set status = 'Validating'
  where id = p_batch_id;

  return query
  select p_batch_id, v_row_count, v_matched_count, v_create_count, v_error_count;
end;
$function$;