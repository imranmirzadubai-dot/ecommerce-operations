-- P12-T193: reconcile historical-import row counts and monetary totals against
-- caller-supplied source control totals. No production business data or staged
-- row data is mutated by this command.

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
  from public.import_rows
  where batch_id = p_batch_id;

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

revoke all on function public.reconcile_import_monetary_counts(uuid, text, integer, numeric, text) from public, anon;
grant execute on function public.reconcile_import_monetary_counts(uuid, text, integer, numeric, text) to authenticated;
