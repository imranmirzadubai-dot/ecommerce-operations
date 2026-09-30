-- P15-T239: harden the historical-import pipeline for runtime execution.
-- The original pipeline was structurally covered but had unqualified import_rows.batch_id
-- references that collide with RETURNS TABLE(batch_id,...). This forward migration preserves
-- behavior while qualifying those references so the complete rehearsal can execute.

create or replace function public.stage_import_file(
  p_source_system text,
  p_source_file text,
  p_rows jsonb,
  p_idempotency_key text
)
returns table(batch_id uuid, row_count integer)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_batch_id uuid;
  v_row_count integer;
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

  if btrim(coalesce(p_source_system, '')) = '' then
    raise exception using errcode='22023', message='Source system is required';
  end if;

  if btrim(coalesce(p_source_file, '')) = '' then
    raise exception using errcode='22023', message='Source file is required';
  end if;

  if jsonb_typeof(p_rows) <> 'array' then
    raise exception using errcode='22023', message='Import rows must be a JSON array';
  end if;

  if jsonb_array_length(p_rows) = 0 then
    raise exception using errcode='22023', message='Import rows must not be empty';
  end if;

  -- Stage the source file only once for a given actor/request. The same request
  -- can be retried safely without creating a second batch or second set of rows.
  select * into v_claim
  from public.claim_command_idempotency(
    'stage_import_file',
    p_idempotency_key,
    md5(concat_ws('|', btrim(p_source_system), btrim(p_source_file), p_rows::text))
  );

  if not v_claim.is_new then
    return query
      select (v_claim.result->>'batch_id')::uuid,
             (v_claim.result->>'row_count')::integer;
    return;
  end if;

  insert into public.import_batches(source_system, source_file, initiated_by, status)
  values(btrim(p_source_system), btrim(p_source_file), v_actor_id, 'Uploaded')
  returning id into v_batch_id;

  insert into public.import_rows(batch_id, source_row_number, source_record_id, raw_data, status)
  select
    v_batch_id,
    ordinality::integer,
    nullif(btrim(elem->>'source_record_id'), ''),
    elem,
    'Pending'
  from jsonb_array_elements(p_rows) with ordinality as rows(elem, ordinality)
  where jsonb_typeof(elem) = 'object';

  select count(*)::integer into v_row_count
  from public.import_rows ir
  where ir.batch_id = v_batch_id;

  if v_row_count <> jsonb_array_length(p_rows) then
    raise exception using errcode='22023', message='Every import row must be a JSON object';
  end if;

  v_result := jsonb_build_object(
    'batch_id', v_batch_id,
    'row_count', v_row_count
  );

  perform public.complete_command_idempotency(
    'stage_import_file',
    p_idempotency_key,
    v_result
  );

  return query select v_batch_id, v_row_count;
end;
$$;

-- Match the repository-wide command access contract: no PUBLIC/anon execution.

create or replace function public.map_import_columns(
  p_batch_id uuid,
  p_mapping jsonb,
  p_idempotency_key text
)
returns table(batch_id uuid, row_count integer)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_status text;
  v_row_count integer;
  v_claim record;
  v_result jsonb;
  v_source_column text;
  v_target_column text;
  v_target_count integer;
  v_mapping_count integer;
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

  if jsonb_typeof(p_mapping) <> 'object' then
    raise exception using errcode='22023', message='Column mapping must be a JSON object';
  end if;

  if jsonb_object_length(p_mapping) = 0 then
    raise exception using errcode='22023', message='Column mapping must not be empty';
  end if;

  -- Every source column maps to one non-empty canonical target column.
  for v_source_column, v_target_column in
    select key, value from jsonb_each_text(p_mapping)
  loop
    if btrim(v_source_column) = '' or btrim(v_target_column) = '' then
      raise exception using errcode='22023', message='Column mapping names must not be empty';
    end if;
  end loop;

  select count(*)::integer, count(distinct btrim(value))::integer
    into v_mapping_count, v_target_count
  from jsonb_each_text(p_mapping);

  if v_mapping_count <> v_target_count then
    raise exception using errcode='22023', message='Column mapping target names must be unique';
  end if;

  select status into v_status
  from public.import_batches
  where id = p_batch_id
    and initiated_by = v_actor_id
  for update;

  if not found then
    raise exception using errcode='42501', message='Import batch is not accessible';
  end if;

  if v_status <> 'Uploaded' then
    raise exception using errcode='55000', message='Import batch must be Uploaded before mapping';
  end if;

  select * into v_claim
  from public.claim_command_idempotency(
    'map_import_columns',
    p_idempotency_key,
    md5(concat_ws('|', p_batch_id::text, p_mapping::text))
  );

  if not v_claim.is_new then
    return query
      select (v_claim.result->>'batch_id')::uuid,
             (v_claim.result->>'row_count')::integer;
    return;
  end if;

  update public.import_rows r
  set normalized_data = mapped.normalized_data,
      status = 'Pending'
  from (
    select r2.id,
           coalesce(
             jsonb_object_agg(btrim(m.value), r2.raw_data -> m.key)
               filter (where r2.raw_data ? m.key),
             '{}'::jsonb
           ) as normalized_data
    from public.import_rows r2
    cross join lateral jsonb_each_text(p_mapping) m
    where r2.batch_id = p_batch_id
      and jsonb_typeof(r2.raw_data) = 'object'
    group by r2.id
  ) mapped
  where r.id = mapped.id;

  select count(*)::integer into v_row_count
  from public.import_rows r
  where r.batch_id = p_batch_id;

  update public.import_batches
  set status = 'Mapping'
  where id = p_batch_id;

  v_result := jsonb_build_object(
    'batch_id', p_batch_id,
    'row_count', v_row_count
  );

  perform public.complete_command_idempotency(
    'map_import_columns',
    p_idempotency_key,
    v_result
  );

  return query select p_batch_id, v_row_count;
end;
$$;

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
  from public.import_rows r where r.batch_id = p_batch_id;

  select count(*)::integer into v_valid_count
  from public.import_rows r
  where r.batch_id = p_batch_id and r.status = 'Valid';

  select count(*)::integer into v_error_count
  from public.import_rows r
  where r.batch_id = p_batch_id and r.status = 'Error';

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

create or replace function public.normalize_import_phone_fields(
  p_batch_id uuid,
  p_phone_fields jsonb,
  p_default_country_code text,
  p_idempotency_key text
)
returns table(batch_id uuid, row_count integer, normalized_count integer, error_count integer)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_status text;
  v_row_count integer;
  v_normalized_count integer;
  v_error_count integer;
  v_claim record;
  v_result jsonb;
  v_country text;
  v_field text;
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

  if jsonb_typeof(p_phone_fields) <> 'array' then
    raise exception using errcode='22023', message='Phone fields must be a JSON array';
  end if;

  v_country := regexp_replace(coalesce(btrim(p_default_country_code), ''), '^\\+', '');
  if v_country <> '' and v_country !~ '^[1-9][0-9]{0,2}$' then
    raise exception using errcode='22023', message='Default country code must contain 1-3 digits';
  end if;

  for v_field in select value from jsonb_array_elements_text(p_phone_fields)
  loop
    if btrim(v_field) = '' then
      raise exception using errcode='22023', message='Phone field names must not be empty';
    end if;
  end loop;

  if (select count(*) from jsonb_array_elements_text(p_phone_fields))
     <> (select count(distinct value) from jsonb_array_elements_text(p_phone_fields)) then
    raise exception using errcode='22023', message='Phone field names must be unique';
  end if;

  select status into v_status
  from public.import_batches
  where id = p_batch_id
    and initiated_by = v_actor_id
  for update;

  if not found then
    raise exception using errcode='42501', message='Import batch is not accessible';
  end if;

  if v_status not in ('Mapping','Validating','Ready') then
    raise exception using errcode='55000', message='Import batch must be Mapping, Validating, or Ready before phone normalization';
  end if;

  select * into v_claim
  from public.claim_command_idempotency(
    'normalize_import_phone_fields',
    p_idempotency_key,
    md5(concat_ws('|', p_batch_id::text, p_phone_fields::text, v_country))
  );

  if not v_claim.is_new then
    return query
      select (v_claim.result->>'batch_id')::uuid,
             (v_claim.result->>'row_count')::integer,
             (v_claim.result->>'normalized_count')::integer,
             (v_claim.result->>'error_count')::integer;
    return;
  end if;

  -- Raw source values remain immutable. Only successfully normalized configured
  -- phone fields are overlaid onto normalized_data; all other mapped fields remain.
  update public.import_rows r
  set normalized_data = r.normalized_data || coalesce(x.phone_data, '{}'::jsonb),
      status = case when x.error_text is null then r.status else 'Error' end,
      error = case when x.error_text is null then r.error else x.error_text end
  from lateral (
    select
      jsonb_object_agg(v.field, v.value) filter (where v.value is not null) as phone_data,
      case when count(v.error_text) filter (where v.error_text is not null) = 0
           then null
           else array_to_string(array_agg(v.error_text order by v.ord) filter (where v.error_text is not null), '; ')
      end as error_text
    from (
      select pf.field, pf.ord,
             case
               when not (r.normalized_data ? pf.field) or r.normalized_data -> pf.field is null then null
               when regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9+]', '', 'g') ~ '^\\+[0-9]{7,15}$'
                 then to_jsonb(regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9+]', '', 'g'))
               when regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^00[0-9]{7,15}$'
                 then to_jsonb('+' || substring(regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9]', '', 'g') from 3))
               when v_country <> ''
                    and regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^0[0-9]{6,14}$'
                 then to_jsonb('+' || v_country || substring(regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9]', '', 'g') from 2))
               when regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^[1-9][0-9]{6,14}$'
                 then to_jsonb('+' || regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9]', '', 'g'))
               else null
             end as value,
             case
               when not (r.normalized_data ? pf.field) or r.normalized_data -> pf.field is null then null
               when regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9+]', '', 'g') ~ '^\\+[0-9]{7,15}$' then null
               when regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^00[0-9]{7,15}$' then null
               when v_country <> '' and regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^0[0-9]{6,14}$' then null
               when regexp_replace(btrim(r.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^[1-9][0-9]{6,14}$' then null
               else 'Invalid phone number: ' || pf.field
             end as error_text
      from jsonb_array_elements_text(p_phone_fields) with ordinality pf(field, ord)
    ) v
  ) x
  where r.batch_id = p_batch_id;

  select count(*)::integer into v_row_count
  from public.import_rows r where r.batch_id = p_batch_id;

  select count(*)::integer into v_normalized_count
  from public.import_rows r
  where r.batch_id = p_batch_id
    and exists (
      select 1
      from jsonb_array_elements_text(p_phone_fields) pf(field)
      where r.normalized_data ? pf.field
        and (r.normalized_data ->> pf.field) ~ '^\\+[1-9][0-9]{6,14}$'
    );

  select count(*)::integer into v_error_count
  from public.import_rows r
  where r.batch_id = p_batch_id and r.status = 'Error';

  update public.import_batches
  set status = case when v_error_count = 0 then 'Ready' else 'Validating' end
  where id = p_batch_id;

  v_result := jsonb_build_object(
    'batch_id', p_batch_id,
    'row_count', v_row_count,
    'normalized_count', v_normalized_count,
    'error_count', v_error_count
  );

  perform public.complete_command_idempotency(
    'normalize_import_phone_fields',
    p_idempotency_key,
    v_result
  );

  return query select p_batch_id, v_row_count, v_normalized_count, v_error_count;
end;
$$;

create or replace function public.assign_import_source_identity(
  p_batch_id uuid,
  p_identity_fields jsonb,
  p_idempotency_key text
)
returns table(batch_id uuid, row_count integer, identity_count integer)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_status text;
  v_source_system text;
  v_source_file text;
  v_row_count integer;
  v_identity_count integer;
  v_claim record;
  v_result jsonb;
  v_field text;
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

  if jsonb_typeof(p_identity_fields) <> 'array' or jsonb_array_length(p_identity_fields) = 0 then
    raise exception using errcode='22023', message='Identity fields must be a non-empty JSON array';
  end if;

  for v_field in select value from jsonb_array_elements_text(p_identity_fields)
  loop
    if btrim(v_field) = '' then
      raise exception using errcode='22023', message='Identity field names must not be empty';
    end if;
  end loop;

  select b.status, b.source_system, b.source_file
    into v_status, v_source_system, v_source_file
  from public.import_batches b
  where b.id = p_batch_id
    and b.initiated_by = v_actor_id
  for update;

  if not found then
    raise exception using errcode='42501', message='Import batch is not accessible';
  end if;

  if v_status not in ('Mapping','Validating','Ready') then
    raise exception using errcode='55000', message='Import batch must be Mapping, Validating, or Ready before source identity assignment';
  end if;

  select * into v_claim
  from public.claim_command_idempotency(
    'assign_import_source_identity',
    p_idempotency_key,
    md5(concat_ws('|', p_batch_id::text, p_identity_fields::text))
  );

  if not v_claim.is_new then
    return query
      select (v_claim.result->>'batch_id')::uuid,
             (v_claim.result->>'row_count')::integer,
             (v_claim.result->>'identity_count')::integer;
    return;
  end if;

  -- raw_data and source_record_id are intentionally untouched by identity assignment.
  update public.import_rows r
  set source_identity = md5(
    concat_ws(
      '|',
      coalesce(v_source_system, ''),
      coalesce(v_source_file, ''),
      coalesce(r.source_record_id, ''),
      coalesce(
        (select string_agg(
           coalesce(r.normalized_data ->> (p_identity_fields ->> (ord - 1)), '<NULL>'),
           '|' order by ord
         )
         from generate_series(1, jsonb_array_length(p_identity_fields)) ord
        ),
        '<NO_IDENTITY_FIELDS>'
      ),
      case when r.source_record_id is null then r.source_row_number::text else '' end
    )
  )
  where r.batch_id = p_batch_id;

  select count(*)::integer into v_row_count
  from public.import_rows r where r.batch_id = p_batch_id;

  select count(*)::integer into v_identity_count
  from public.import_rows r
  where r.batch_id = p_batch_id and source_identity is not null;

  v_result := jsonb_build_object(
    'batch_id', p_batch_id,
    'row_count', v_row_count,
    'identity_count', v_identity_count
  );

  perform public.complete_command_idempotency(
    'assign_import_source_identity',
    p_idempotency_key,
    v_result
  );

  return query select p_batch_id, v_row_count, v_identity_count;
end;
$$;

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
    and r.r.customer_match_status is distinct from 'Matched'
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
  from public.import_rows r where r.batch_id = p_batch_id;

  select count(*)::integer into v_matched_count
  from public.import_rows r
  where r.batch_id = p_batch_id and r.customer_match_status = 'Matched';

  select count(*)::integer into v_create_count
  from public.import_rows r
  where r.batch_id = p_batch_id and r.customer_match_status = 'Create';

  select count(*)::integer into v_error_count
  from public.import_rows r
  where r.batch_id = p_batch_id and r.customer_match_status = 'Exception';

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
  from public.import_rows r
  where r.batch_id = p_batch_id;

  select count(*)::integer into v_create_count
  from public.import_rows r
  where r.batch_id = p_batch_id and r.status = 'Create';

  select count(*)::integer into v_update_count
  from public.import_rows r
  where r.batch_id = p_batch_id and r.status = 'Matched';

  select count(*)::integer into v_error_count
  from public.import_rows r
  where r.batch_id = p_batch_id and r.status in ('Error','Exception');

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
  from public.import_rows r
  where r.batch_id = p_batch_id;

  select count(*)::integer into v_matched_count
  from public.import_rows r
  where r.batch_id = p_batch_id
    and r.customer_match_status = 'Matched';

  select count(*)::integer into v_create_count
  from public.import_rows r
  where r.batch_id = p_batch_id
    and r.customer_match_status = 'Create';

  select count(*)::integer into v_exception_count
  from public.import_rows r
  where r.batch_id = p_batch_id
    and r.customer_match_status = 'Exception';

  select count(*)::integer into v_unclassified_count
  from public.import_rows r
  where r.batch_id = p_batch_id
    and r.customer_match_status is distinct from 'Matched'
    and r.customer_match_status is distinct from 'Create'
    and r.customer_match_status is distinct from 'Exception';

  select count(*)::integer into v_status_mismatch_count
  from public.import_rows r
  where r.batch_id = p_batch_id
    and (
      (customer_match_status in ('Matched','Create') and r.status <> 'Valid')
      or (customer_match_status = 'Exception' and r.status <> 'Error')
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

create or replace function public.reconcile_import_monetary_counts(
  p_batch_id uuid,
  p_amount_field text,
  p_expected_row_count integer,
  p_expected_amount numeric(12,2),
  p_idempotency_key text
)
returns table(
  batch_id uuid,
  row_count integer,
  expected_row_count integer,
  count_delta integer,
  actual_amount numeric(12,2),
  expected_amount numeric(12,2),
  amount_delta numeric(12,2),
  invalid_amount_count integer,
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
  v_invalid_amount_count integer;
  v_actual_amount numeric(12,2);
  v_count_delta integer;
  v_amount_delta numeric(12,2);
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

  if btrim(coalesce(p_amount_field, '')) = '' then
    raise exception using errcode='22023', message='Amount field is required';
  end if;

  if p_expected_row_count is null or p_expected_row_count < 0 then
    raise exception using errcode='22023', message='Expected row count must be non-negative';
  end if;

  if p_expected_amount is null or p_expected_amount < 0 then
    raise exception using errcode='22023', message='Expected amount must be non-negative';
  end if;

  select b.status into v_status
  from public.import_batches b
  where b.id = p_batch_id
    and b.initiated_by = v_actor_id;

  if not found then
    raise exception using errcode='42501', message='Import batch is not accessible';
  end if;

  if v_status not in ('Validating','Ready') then
    raise exception using errcode='55000', message='Import batch must be Validating or Ready before monetary/count reconciliation';
  end if;

  select * into v_claim
  from public.claim_command_idempotency(
    'reconcile_import_monetary_counts',
    p_idempotency_key,
    md5(concat_ws('|', p_batch_id::text, btrim(p_amount_field), p_expected_row_count::text, p_expected_amount::text))
  );

  if not v_claim.is_new then
    return query
      select (v_claim.result->>'batch_id')::uuid,
             (v_claim.result->>'row_count')::integer,
             (v_claim.result->>'expected_row_count')::integer,
             (v_claim.result->>'count_delta')::integer,
             (v_claim.result->>'actual_amount')::numeric(12,2),
             (v_claim.result->>'expected_amount')::numeric(12,2),
             (v_claim.result->>'amount_delta')::numeric(12,2),
             (v_claim.result->>'invalid_amount_count')::integer,
             (v_claim.result->>'reconciled')::boolean;
    return;
  end if;

  select count(*)::integer into v_row_count
  from public.import_rows r
  where r.batch_id = p_batch_id;

  select count(*)::integer into v_invalid_amount_count
  from public.import_rows r
  where r.batch_id = p_batch_id
    and (
      not (r.normalized_data ? btrim(p_amount_field))
      or r.normalized_data -> btrim(p_amount_field) is null
      or btrim(coalesce(r.normalized_data ->> btrim(p_amount_field), '')) = ''
      or btrim(r.normalized_data ->> btrim(p_amount_field)) !~ '^(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)$'
      or (r.normalized_data ->> btrim(p_amount_field))::numeric < 0
      or (
        position('.' in btrim(r.normalized_data ->> btrim(p_amount_field))) > 0
        and length(split_part(btrim(r.normalized_data ->> btrim(p_amount_field)), '.', 2)) > 2
      )
    );

  select coalesce(sum((r.normalized_data ->> btrim(p_amount_field))::numeric), 0::numeric(12,2))::numeric(12,2)
    into v_actual_amount
  from public.import_rows r
  where r.batch_id = p_batch_id
    and r.normalized_data ? btrim(p_amount_field)
    and r.normalized_data -> btrim(p_amount_field) is not null
    and btrim(coalesce(r.normalized_data ->> btrim(p_amount_field), '')) <> ''
    and btrim(r.normalized_data ->> btrim(p_amount_field)) ~ '^(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)$'
    and (r.normalized_data ->> btrim(p_amount_field))::numeric >= 0
    and not (
      position('.' in btrim(r.normalized_data ->> btrim(p_amount_field))) > 0
      and length(split_part(btrim(r.normalized_data ->> btrim(p_amount_field)), '.', 2)) > 2
    );

  v_count_delta := v_row_count - p_expected_row_count;
  v_amount_delta := round(v_actual_amount - p_expected_amount, 2)::numeric(12,2);
  v_reconciled :=
    v_row_count = p_expected_row_count
    and v_invalid_amount_count = 0
    and v_amount_delta = 0::numeric(12,2);

  v_result := jsonb_build_object(
    'batch_id', p_batch_id,
    'row_count', v_row_count,
    'expected_row_count', p_expected_row_count,
    'count_delta', v_count_delta,
    'actual_amount', v_actual_amount,
    'expected_amount', p_expected_amount,
    'amount_delta', v_amount_delta,
    'invalid_amount_count', v_invalid_amount_count,
    'reconciled', v_reconciled
  );

  update public.import_batches
  set reconciliation_summary = coalesce(reconciliation_summary, '{}'::jsonb)
    || jsonb_build_object('monetary_count_reconciliation', v_result)
  where id = p_batch_id
    and initiated_by = v_actor_id;

  perform public.complete_command_idempotency(
    'reconcile_import_monetary_counts',
    p_idempotency_key,
    v_result
  );

  return query
    select p_batch_id,
           v_row_count,
           p_expected_row_count,
           v_count_delta,
           v_actual_amount,
           p_expected_amount,
           v_amount_delta,
           v_invalid_amount_count,
           v_reconciled;
end;
$$;

create or replace function public.import_historical_batch(
  p_batch_id uuid,
  p_field_map jsonb,
  p_idempotency_key text
)
returns table(
  batch_id uuid,
  row_count integer,
  customer_create_count integer,
  customer_reuse_count integer,
  order_create_count integer,
  order_item_create_count integer
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_status text;
  v_row_count integer;
  v_customer_create_count integer := 0;
  v_customer_reuse_count integer := 0;
  v_order_create_count integer := 0;
  v_order_item_create_count integer := 0;
  v_claim record;
  v_result jsonb;
  v_summary jsonb;
  v_staging_reconciled boolean;
  v_monetary_reconciled boolean;
  v_name_field text;
  v_phone_field text;
  v_address_field text;
  v_city_field text;
  v_order_date_field text;
  v_amount_field text;
  v_item_description_field text;
  v_quantity_field text;
  v_customer_id uuid;
  v_order_id uuid;
  v_order_date date;
  v_amount numeric(12,2);
  v_quantity integer;
  v_name text;
  v_phone text;
  v_item_description text;
  r record;
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
  if jsonb_typeof(p_field_map) <> 'object' then
    raise exception using errcode='22023', message='Production import field map must be a JSON object';
  end if;

  v_name_field := btrim(coalesce(p_field_map->>'customer_name_field', ''));
  v_phone_field := btrim(coalesce(p_field_map->>'phone_field', ''));
  v_address_field := btrim(coalesce(p_field_map->>'address_field', ''));
  v_city_field := btrim(coalesce(p_field_map->>'city_field', ''));
  v_order_date_field := btrim(coalesce(p_field_map->>'order_date_field', ''));
  v_amount_field := btrim(coalesce(p_field_map->>'amount_field', ''));
  v_item_description_field := btrim(coalesce(p_field_map->>'item_description_field', ''));
  v_quantity_field := btrim(coalesce(p_field_map->>'quantity_field', ''));

  if v_name_field = '' or v_phone_field = '' or v_order_date_field = ''
     or v_amount_field = '' or v_item_description_field = '' or v_quantity_field = '' then
    raise exception using errcode='22023', message='Production import requires customer name, phone, order date, amount, item description, and quantity fields';
  end if;
  if v_address_field = '' then v_address_field := null; end if;
  if v_city_field = '' then v_city_field := null; end if;

  select b.status, b.reconciliation_summary into v_status, v_summary
  from public.import_batches b
  where b.id = p_batch_id and b.initiated_by = v_actor_id
  for update;
  if not found then
    raise exception using errcode='42501', message='Import batch is not accessible';
  end if;
  if v_status <> 'Ready' then
    raise exception using errcode='55000', message='Import batch must be Ready before production import';
  end if;

  v_staging_reconciled := coalesce((v_summary->'staging_reconciliation'->>'reconciled')::boolean, false);
  v_monetary_reconciled := coalesce((v_summary->'monetary_count_reconciliation'->>'reconciled')::boolean, false);
  if not v_staging_reconciled or not v_monetary_reconciled then
    raise exception using errcode='55000', message='Import batch must pass staging and monetary/count reconciliation before production import';
  end if;

  select * into v_claim from public.claim_command_idempotency(
    'import_historical_batch', p_idempotency_key,
    md5(concat_ws('|', p_batch_id::text, p_field_map::text))
  );
  if not v_claim.is_new then
    return query select (v_claim.result->>'batch_id')::uuid,
      (v_claim.result->>'row_count')::integer,
      (v_claim.result->>'customer_create_count')::integer,
      (v_claim.result->>'customer_reuse_count')::integer,
      (v_claim.result->>'order_create_count')::integer,
      (v_claim.result->>'order_item_create_count')::integer;
    return;
  end if;

  update public.import_batches set status='Importing', started_at=coalesce(started_at, now()) where id=p_batch_id;
  select count(*)::integer into v_row_count from public.import_rows ir where ir.batch_id=p_batch_id;
  if v_row_count = 0 then
    raise exception using errcode='22023', message='Import batch contains no rows';
  end if;
  if exists (select 1 from public.import_rows r where r.batch_id=p_batch_id and (r.status <> 'Valid' or r.customer_match_status not in ('Matched','Create'))) then
    raise exception using errcode='55000', message='Every import row must be Valid and customer-classified as Matched or Create';
  end if;

  for r in select * from public.import_rows ir where ir.batch_id=p_batch_id order by ir.source_row_number loop
    v_name := btrim(r.normalized_data ->> v_name_field);
    v_phone := btrim(r.normalized_data ->> v_phone_field);
    v_order_date := (r.normalized_data ->> v_order_date_field)::date;
    v_amount := (r.normalized_data ->> v_amount_field)::numeric(12,2);
    v_item_description := btrim(r.normalized_data ->> v_item_description_field);
    v_quantity := (r.normalized_data ->> v_quantity_field)::integer;
    if v_name='' or v_phone !~ '^\\+[1-9][0-9]{6,14}$' or v_item_description='' or v_quantity <= 0 or v_amount < 0 then
      raise exception using errcode='22023', message='Production import row contains invalid canonical customer/order/item values';
    end if;

    if r.customer_match_status='Matched' then
      v_customer_id := r.matched_customer_id;
      if v_customer_id is null then
        raise exception using errcode='55000', message='Matched import row is missing matched customer';
      end if;
      v_customer_reuse_count := v_customer_reuse_count + 1;
    else
      insert into public.customers(name, phone, normalized_phone, address, city)
      values(v_name, v_phone, v_phone,
        case when v_address_field is null then null else nullif(btrim(r.normalized_data ->> v_address_field),'') end,
        case when v_city_field is null then null else nullif(btrim(r.normalized_data ->> v_city_field),'') end)
      on conflict (normalized_phone) do nothing returning id into v_customer_id;
      if v_customer_id is null then
        select c.id into v_customer_id from public.customers c where c.normalized_phone=v_phone;
        v_customer_reuse_count := v_customer_reuse_count + 1;
      else
        v_customer_create_count := v_customer_create_count + 1;
      end if;
    end if;

    insert into public.orders(customer_id, order_date, currency_code, original_amount, lifecycle_state, notes, created_by)
    values(v_customer_id, v_order_date, 'AED', v_amount, 'Completed', 'Historical import; source row '||r.source_row_number::text, v_actor_id)
    returning id into v_order_id;
    v_order_create_count := v_order_create_count + 1;

    insert into public.order_items(order_id, line_no, description, quantity)
    values(v_order_id,1,v_item_description,v_quantity);
    v_order_item_create_count := v_order_item_create_count + 1;

    insert into public.order_events(order_id,event_type,performed_by,notes,metadata)
    values(v_order_id,'Historical Import',v_actor_id,
      'Imported from historical source row '||r.source_row_number::text,
      jsonb_build_object('batch_id',p_batch_id,'source_row_number',r.source_row_number,'source_record_id',r.source_record_id,'source_identity',r.source_identity));
  end loop;

  update public.import_batches set status='Completed', completed_at=now() where id=p_batch_id;
  v_result := jsonb_build_object('batch_id',p_batch_id,'row_count',v_row_count,'customer_create_count',v_customer_create_count,'customer_reuse_count',v_customer_reuse_count,'order_create_count',v_order_create_count,'order_item_create_count',v_order_item_create_count);
  perform public.complete_command_idempotency('import_historical_batch',p_idempotency_key,v_result);
  return query select p_batch_id,v_row_count,v_customer_create_count,v_customer_reuse_count,v_order_create_count,v_order_item_create_count;
end;
$$;

revoke all on function public.stage_import_file(text,text,jsonb,text) from public, anon;
grant execute on function public.stage_import_file(text,text,jsonb,text) to authenticated;
revoke all on function public.map_import_columns(uuid,jsonb,text) from public, anon;
grant execute on function public.map_import_columns(uuid,jsonb,text) to authenticated;
revoke all on function public.validate_import_rows(uuid,jsonb,jsonb,jsonb,jsonb,text) from public, anon;
grant execute on function public.validate_import_rows(uuid,jsonb,jsonb,jsonb,jsonb,text) to authenticated;
revoke all on function public.normalize_import_phone_fields(uuid,jsonb,text,text) from public, anon;
grant execute on function public.normalize_import_phone_fields(uuid,jsonb,text,text) to authenticated;
revoke all on function public.assign_import_source_identity(uuid,jsonb,text) from public, anon;
grant execute on function public.assign_import_source_identity(uuid,jsonb,text) to authenticated;
revoke all on function public.match_import_customers(uuid,text,text) from public, anon;
grant execute on function public.match_import_customers(uuid,text,text) to authenticated;
revoke all on function public.preview_import_customer_changes(uuid,text) from public, anon;
grant execute on function public.preview_import_customer_changes(uuid,text) to authenticated;
revoke all on function public.reconcile_import_staging(uuid,text) from public, anon;
grant execute on function public.reconcile_import_staging(uuid,text) to authenticated;
revoke all on function public.reconcile_import_monetary_counts(uuid,text,integer,numeric,text) from public, anon;
grant execute on function public.reconcile_import_monetary_counts(uuid,text,integer,numeric,text) to authenticated;
revoke all on function public.import_historical_batch(uuid,jsonb,text) from public, anon;
grant execute on function public.import_historical_batch(uuid,jsonb,text) to authenticated;
