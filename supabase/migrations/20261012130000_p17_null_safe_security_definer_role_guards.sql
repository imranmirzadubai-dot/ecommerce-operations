begin;

-- P17: harden NULL-sensitive role checks in existing SECURITY DEFINER functions.
-- This forward-only migration changes function definitions only; it does not
-- alter tables, data, grants, function signatures, or application role membership.
do $migration$
declare
  v record;
  v_definition text;
  v_updated text;
  v_fixed integer := 0;
begin
  for v in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.prosecdef
      and (
        pg_get_functiondef(p.oid) ~* 'public\.app_role\(\)\s*(<>|!=)\s*''admin'''
        or pg_get_functiondef(p.oid) ~* 'public\.app_role\(\)\s+not\s+in\s*\('
      )
  loop
    v_definition := pg_get_functiondef(v.oid);
    v_updated := regexp_replace(
      v_definition,
      'public\.app_role\(\)\s*(<>|!=)\s*''admin''',
      'public.app_role() IS DISTINCT FROM ''admin''',
      'gi'
    );
    v_updated := regexp_replace(
      v_updated,
      'public\.app_role\(\)\s+not\s+in\s*\(',
      'public.app_role() IS NULL OR public.app_role() NOT IN (',
      'gi'
    );

    if v_updated = v_definition then
      raise exception 'Could not harden identified role guard for function OID %', v.oid;
    end if;

    execute v_updated;
    v_fixed := v_fixed + 1;
  end loop;

  if v_fixed = 0 then
    raise exception 'Expected NULL-sensitive SECURITY DEFINER role guards to harden';
  end if;
end;
$migration$;

commit;
