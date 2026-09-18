-- P12-T189: assign a deterministic identity to each staged historical-import row.
-- Identity is derived from source metadata plus an ordered set of mapped values.
-- Raw source data and source_record_id remain unchanged.

alter table public.import_rows
  add column if not exists source_identity text;

create index if not exists idx_import_rows_source_identity
  on public.import_rows(source_identity);

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
  from public.import_rows where batch_id = p_batch_id;

  select count(*)::integer into v_identity_count
  from public.import_rows
  where batch_id = p_batch_id and source_identity is not null;

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

revoke all on function public.assign_import_source_identity(uuid, jsonb, text) from public, anon;
grant execute on function public.assign_import_source_identity(uuid, jsonb, text) to authenticated;
