-- P12-T185: stage a historical import file as an immutable batch/row input set.
-- The uploaded file is represented by source_file metadata and its parsed source rows
-- are retained verbatim in import_rows.raw_data. Mapping/validation are later milestones.

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
  v_row jsonb;
  v_source_record_id text;
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
  from public.import_rows
  where batch_id = v_batch_id;

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

revoke all on function public.stage_import_file(text, text, jsonb, text) from public;
grant execute on function public.stage_import_file(text, text, jsonb, text) to authenticated;
