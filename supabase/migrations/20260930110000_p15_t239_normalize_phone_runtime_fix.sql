-- P15-T239: fix runtime execution of phone normalization.
-- The previous hardening migration used UPDATE ... FROM LATERAL while referencing
-- the UPDATE target alias inside the lateral subquery. PostgreSQL rejects that
-- reference at execution time. This migration preserves the logic while using a
-- separate source-row alias for the lateral calculation.

CREATE OR REPLACE FUNCTION public.normalize_import_phone_fields(p_batch_id uuid, p_phone_fields jsonb, p_default_country_code text, p_idempotency_key text)
 RETURNS TABLE(batch_id uuid, row_count integer, normalized_count integer, error_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
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

  v_country := regexp_replace(coalesce(btrim(p_default_country_code), ''), '^\+', '');
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
      status = case when x.error_text is null then r.status else 'Invalid' end,
      error = case when x.error_text is null then r.error else x.error_text end
  from public.import_rows source_row
  cross join lateral (
    select
      jsonb_object_agg(v.field, v.value) filter (where v.value is not null) as phone_data,
      case when count(v.error_text) filter (where v.error_text is not null) = 0
           then null
           else array_to_string(array_agg(v.error_text order by v.ord) filter (where v.error_text is not null), '; ')
      end as error_text
    from (
      select pf.field, pf.ord,
             case
               when not (source_row.normalized_data ? pf.field) or source_row.normalized_data -> pf.field is null then null
               when regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9+]', '', 'g') ~ '^\+[0-9]{7,15}$'
                 then to_jsonb(regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9+]', '', 'g'))
               when regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^00[0-9]{7,15}$'
                 then to_jsonb('+' || substring(regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9]', '', 'g') from 3))
               when v_country <> ''
                    and regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^0[0-9]{6,14}$'
                 then to_jsonb('+' || v_country || substring(regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9]', '', 'g') from 2))
               when regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^[1-9][0-9]{6,14}$'
                 then to_jsonb('+' || regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9]', '', 'g'))
               else null
             end as value,
             case
               when not (source_row.normalized_data ? pf.field) or source_row.normalized_data -> pf.field is null then null
               when regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9+]', '', 'g') ~ '^\+[0-9]{7,15}$' then null
               when regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^00[0-9]{7,15}$' then null
               when v_country <> '' and regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^0[0-9]{6,14}$' then null
               when regexp_replace(btrim(source_row.normalized_data ->> pf.field), '[^0-9]', '', 'g') ~ '^[1-9][0-9]{6,14}$' then null
               else 'Invalid phone number: ' || pf.field
             end as error_text
      from jsonb_array_elements_text(p_phone_fields) with ordinality pf(field, ord)
    ) v
  ) x
  where r.id = source_row.id
    and source_row.batch_id = p_batch_id;
