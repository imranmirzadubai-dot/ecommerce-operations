-- P12-T196: generate a deterministic Admin-only report from retained import-row errors.
-- Error details remain authoritative on public.import_rows; this command provides a
-- stable, source-lineage-aware report without mutating staging or production data.

create or replace function public.generate_import_error_report(
  p_batch_id uuid
)
returns table(
  batch_id uuid,
  source_row_number integer,
  source_record_id text,
  source_identity text,
  error text
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_exists boolean;
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

  select exists(
    select 1
    from public.import_batches b
    where b.id = p_batch_id
      and b.initiated_by = v_actor_id
  ) into v_exists;

  if not v_exists then
    raise exception using errcode='42501', message='Import batch is not accessible';
  end if;

  return query
  select
    r.batch_id,
    r.source_row_number,
    r.source_record_id,
    r.source_identity,
    r.error
  from public.import_rows r
  where r.batch_id = p_batch_id
    and r.status = 'Error'
    and r.error is not null
    and btrim(r.error) <> ''
  order by r.source_row_number, r.id;
end;
$$;

revoke all on function public.generate_import_error_report(uuid) from public, anon;
grant execute on function public.generate_import_error_report(uuid) to authenticated;
