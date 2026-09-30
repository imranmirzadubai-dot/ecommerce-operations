do $$
declare v_def text;
begin
  select pg_get_functiondef('public.reconcile_import_staging(uuid,text)'::regprocedure)
    into v_def;
  if position('set reconciliation_summary = v_result' in v_def) = 0 then
    raise exception 'P15-T239 migration guard failed for reconcile_import_staging summary contract';
  end if;
  v_def := replace(v_def,
    'set reconciliation_summary = v_result',
    'set reconciliation_summary = coalesce(reconciliation_summary, ''{}''::jsonb)
    || jsonb_build_object(''staging_reconciliation'', v_result)');
  execute v_def;
end $$;
