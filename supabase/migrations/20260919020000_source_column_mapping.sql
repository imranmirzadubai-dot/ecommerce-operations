-- P12-T186: map retained source columns into canonical normalized_data.
-- Mapping is applied to the staged import batch transactionally; validation is a later milestone.

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
  from public.import_rows
  where batch_id = p_batch_id;

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

revoke all on function public.map_import_columns(uuid, jsonb, text) from public, anon;
grant execute on function public.map_import_columns(uuid, jsonb, text) to authenticated;
