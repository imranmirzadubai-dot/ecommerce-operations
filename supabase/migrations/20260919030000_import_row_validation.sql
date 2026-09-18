-- P12-T187: validate mapped historical-import rows before downstream normalization/import.
-- Required fields, declared types, ISO dates, and non-negative monetary amounts are
-- evaluated against import_rows.normalized_data. Invalid rows retain their data and
-- receive a deterministic error message; no production business data is changed.

create or replace function public.validate_import_rows(
  p_batch_id uuid,
  p_required_fields jsonb,
  p_type_map jsonb,
  p_date_fields jsonb,
  p_amount_fields jsonb,
  p_idempotency_key text
)
returns table(batch_id uuid, row_count integer, valid_count integer, error_count integer)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_status text;
  v_row_count integer;
  v_valid_count integer;
  v_error_count integer;
  v_claim record;
  v_result jsonb;
  v_field text;
  v_type text;
  v_value text;
  v_error text;
  v_errors text[];
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

  if jsonb_typeof(p_required_fields) <> 'array' then
    raise exception using errcode='22023', message='Required fields must be a JSON array';
  end if;

  if jsonb_typeof(p_type_map) <> 'object' then
    raise exception using errcode='22023', message='Type map must be a JSON object';
  end if;

  if jsonb_typeof(p_date_fields) <> 'array' then
    raise exception using errcode='22023', message='Date fields must be a JSON array';
  end if;

  if jsonb_typeof(p_amount_fields) <> 'array' then
    raise exception using errcode='22023', message='Amount fields must be a JSON array';
  end if;

  -- All validation configuration names must be non-empty. Date/amount fields are
  -- additionally required to have a declared type so the contract is deterministic.
  for v_field in select value from jsonb_array_elements_text(p_required_fields)
  loop
    if btrim(v_field) = '' then
      raise exception using errcode='22023', message='Required field names must not be empty';
    end if;
  end loop;

  for v_field, v_type in select key, value from jsonb_each_text(p_type_map)
  loop
    if btrim(v_field) = '' or btrim(v_type) = '' then
      raise exception using errcode='22023', message='Type map names and types must not be empty';
    end if;
    if lower(btrim(v_type)) not in ('text','integer','number','date','boolean') then
      raise exception using errcode='22023', message='Unsupported import field type';
    end if;
  end loop;

  for v_field in select value from jsonb_array_elements_text(p_date_fields)
  loop
    if btrim(v_field) = '' then
      raise exception using errcode='22023', message='Date field names must not be empty';
    end if;
    if coalesce(lower(p_type_map ->> v_field), '') <> 'date' then
      raise exception using errcode='22023', message='Date fields must be declared as date';
    end if;
  end loop;

  for v_field in select value from jsonb_array_elements_text(p_amount_fields)
  loop
    if btrim(v_field) = '' then
      raise exception using errcode='22023', message='Amount field names must not be empty';
    end if;
    if coalesce(lower(p_type_map ->> v_field), '') not in ('number','integer') then
      raise exception using errcode='22023', message='Amount fields must be numeric';
    end if;
  end loop;

  select status into v_status
  from public.import_batches
  where id = p_batch_id
    and initiated_by = v_actor_id
  for update;

  if not found then
    raise exception using errcode='42501', message='Import batch is not accessible';
  end if;

  if v_status <> 'Mapping' then
    raise exception using errcode='55000', message='Import batch must be Mapping before validation';
  end if;

  select * into v_claim
  from public.claim_command_idempotency(
    'validate_import_rows',
    p_idempotency_key,
    md5(concat_ws('|', p_batch_id::text, p_required_fields::text, p_type_map::text, p_date_fields::text, p_amount_fields::text))
  );

  if not v_claim.is_new then
    return query
      select (v_claim.result->>'batch_id')::uuid,
             (v_claim.result->>'row_count')::integer,
             (v_claim.result->>'valid_count')::integer,
             (v_claim.result->>'error_count')::integer;
    return;
  end if;

  -- Validate every staged row independently. Existing normalized_data and raw_data
  -- are retained unchanged; only validation status/error are updated.
  for v_field in select value from jsonb_array_elements_text(p_required_fields)
  loop
    null;
  end loop;

  update public.import_rows r
  set status = case when v_errors.errors is null then 'Valid' else 'Error' end,
      error = v_errors.errors
  from (
    select r2.id,
           case when cardinality(errs.errors) = 0 then null else array_to_string(errs.errors, '; ') end as errors
    from public.import_rows r2
    cross join lateral (
      select array_agg(msg order by ord) filter (where msg is not null) as errors
      from (
        select rf.ord,
               case
                 when not (r2.normalized_data ? rf.field)
                   or r2.normalized_data -> rf.field is null
                   or (jsonb_typeof(r2.normalized_data -> rf.field) = 'string' and btrim(r2.normalized_data ->> rf.field) = '')
                 then 'Missing required field: ' || rf.field
               end as msg
        from jsonb_array_elements_text(p_required_fields) with ordinality rf(field, ord)

        union all

        select tm.ord,
               case
                 when not (r2.normalized_data ? tm.field) or r2.normalized_data -> tm.field is null then null
                 when lower(tm.type) = 'text' and jsonb_typeof(r2.normalized_data -> tm.field) <> 'string'
                   then 'Invalid text type: ' || tm.field
                 when lower(tm.type) = 'integer' and (
                   jsonb_typeof(r2.normalized_data -> tm.field) not in ('number','string')
                   or (jsonb_typeof(r2.normalized_data -> tm.field) = 'string' and btrim(r2.normalized_data ->> tm.field) !~ '^-?[0-9]+$')
                 ) then 'Invalid integer type: ' || tm.field
                 when lower(tm.type) = 'number' and (
                   jsonb_typeof(r2.normalized_data -> tm.field) not in ('number','string')
                   or (jsonb_typeof(r2.normalized_data -> tm.field) = 'string' and btrim(r2.normalized_data ->> tm.field) !~ '^-?(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)$')
                 ) then 'Invalid number type: ' || tm.field
                 when lower(tm.type) = 'date' and (
                   jsonb_typeof(r2.normalized_data -> tm.field) <> 'string'
                   or btrim(r2.normalized_data ->> tm.field) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   or not pg_input_is_valid(btrim(r2.normalized_data ->> tm.field), 'date'::regtype)
                 ) then 'Invalid date: ' || tm.field
                 when lower(tm.type) = 'boolean' and (
                   jsonb_typeof(r2.normalized_data -> tm.field) <> 'boolean'
                   and (jsonb_typeof(r2.normalized_data -> tm.field) <> 'string' or lower(btrim(r2.normalized_data ->> tm.field)) not in ('true','false'))
                 ) then 'Invalid boolean type: ' || tm.field
               end as msg
        from jsonb_each_text(p_type_map) with ordinality tm(field, type, ord)

        union all

        select af.ord,
               case
                 when not (r2.normalized_data ? af.field) or r2.normalized_data -> af.field is null then null
                 when btrim(r2.normalized_data ->> af.field) !~ '^-?(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)$'
                   then 'Invalid amount: ' || af.field
                 when (r2.normalized_data ->> af.field)::numeric < 0
                   then 'Amount must be non-negative: ' || af.field
                 when position('.' in btrim(r2.normalized_data ->> af.field)) > 0
                   and length(split_part(btrim(r2.normalized_data ->> af.field), '.', 2)) > 2
                   then 'Amount must have at most 2 decimal places: ' || af.field
               end as msg
        from jsonb_array_elements_text(p_amount_fields) with ordinality af(field, ord)

        union all

        select df.ord,
               case
                 when not (r2.normalized_data ? df.field) or r2.normalized_data -> df.field is null then null
                 when jsonb_typeof(r2.normalized_data -> df.field) <> 'string'
                   or btrim(r2.normalized_data ->> df.field) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   or not pg_input_is_valid(btrim(r2.normalized_data ->> df.field), 'date'::regtype)
                   then 'Invalid date: ' || df.field
               end as msg
        from jsonb_array_elements_text(p_date_fields) with ordinality df(field, ord)
      ) validation_messages
    ) errs
    where r2.batch_id = p_batch_id
  ) v_errors
  where r.id = v_errors.id;

  select count(*)::integer into v_row_count
  from public.import_rows where batch_id = p_batch_id;

  select count(*)::integer into v_valid_count
  from public.import_rows where batch_id = p_batch_id and status = 'Valid';

  select count(*)::integer into v_error_count
  from public.import_rows where batch_id = p_batch_id and status = 'Error';

  update public.import_batches
  set status = case when v_error_count = 0 then 'Ready' else 'Validating' end
  where id = p_batch_id;

  v_result := jsonb_build_object(
    'batch_id', p_batch_id,
    'row_count', v_row_count,
    'valid_count', v_valid_count,
    'error_count', v_error_count
  );

  perform public.complete_command_idempotency(
    'validate_import_rows',
    p_idempotency_key,
    v_result
  );

  return query select p_batch_id, v_row_count, v_valid_count, v_error_count;
end;
$$;

revoke all on function public.validate_import_rows(uuid, jsonb, jsonb, jsonb, jsonb, text) from public, anon;
grant execute on function public.validate_import_rows(uuid, jsonb, jsonb, jsonb, jsonb, text) to authenticated;
