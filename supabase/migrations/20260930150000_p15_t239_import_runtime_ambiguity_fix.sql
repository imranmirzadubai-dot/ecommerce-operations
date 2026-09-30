do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.assign_import_source_identity(uuid,jsonb,text)'::regprocedure)
    into v_def;
  if position('from public.import_rows where batch_id = p_batch_id' in v_def) = 0
     or position('from public.import_rows
  where batch_id = p_batch_id and source_identity is not null' in v_def) = 0 then
    raise exception 'P15-T239 migration guard failed for assign_import_source_identity';
  end if;
  v_def := replace(v_def,
    'from public.import_rows where batch_id = p_batch_id',
    'from public.import_rows ir where ir.batch_id = p_batch_id');
  v_def := replace(v_def,
    'from public.import_rows
  where batch_id = p_batch_id and source_identity is not null',
    'from public.import_rows ir
  where ir.batch_id = p_batch_id and ir.source_identity is not null');
  execute v_def;

  select pg_get_functiondef('public.reconcile_import_staging(uuid,text)'::regprocedure)
    into v_def;
  if position('where batch_id = p_batch_id' in v_def) = 0 then
    raise exception 'P15-T239 migration guard failed for reconcile_import_staging';
  end if;
  v_def := replace(v_def,
    'from public.import_rows
  where batch_id = p_batch_id',
    'from public.import_rows ir
  where ir.batch_id = p_batch_id');
  v_def := replace(v_def, 'customer_match_status', 'ir.customer_match_status');
  v_def := replace(v_def, 'and status <>', 'and ir.status <>');
  execute v_def;

  select pg_get_functiondef('public.reconcile_import_monetary_counts(uuid,text,integer,numeric,text)'::regprocedure)
    into v_def;
  if position('from public.import_rows
  where batch_id = p_batch_id;' in v_def) = 0 then
    raise exception 'P15-T239 migration guard failed for reconcile_import_monetary_counts';
  end if;
  v_def := replace(v_def,
    'from public.import_rows
  where batch_id = p_batch_id;',
    'from public.import_rows ir
  where ir.batch_id = p_batch_id;');
  execute v_def;

  select pg_get_functiondef('public.import_historical_batch(uuid,jsonb,text)'::regprocedure)
    into v_def;
  if position('  r record;' in v_def) = 0
     or position('select count(*)::integer into v_row_count from public.import_rows where batch_id=p_batch_id;' in v_def) = 0
     or position('from public.import_rows r where r.batch_id=p_batch_id' in v_def) = 0
     or position('for r in select * from public.import_rows where batch_id=p_batch_id order by source_row_number loop' in v_def) = 0 then
    raise exception 'P15-T239 migration guard failed for import_historical_batch';
  end if;
  v_def := replace(v_def, '  r record;', '  r public.import_rows%rowtype;');
  v_def := replace(v_def,
    'from public.import_rows r where r.batch_id=p_batch_id',
    'from public.import_rows ir where ir.batch_id=p_batch_id');
  v_def := replace(v_def,
    'select count(*)::integer into v_row_count from public.import_rows where batch_id=p_batch_id;',
    'select count(*)::integer into v_row_count from public.import_rows ir where ir.batch_id=p_batch_id;');
  v_def := replace(v_def,
    'for r in select * from public.import_rows where batch_id=p_batch_id order by source_row_number loop',
    'for r in select ir.* from public.import_rows ir where ir.batch_id=p_batch_id order by ir.source_row_number loop');
  execute v_def;
end $$;
