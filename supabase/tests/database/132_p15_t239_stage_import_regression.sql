-- P15-T239: regression coverage for the stage_import_file batch_id ambiguity.
begin;

select plan(7);

select ok(
  (select count(*) = 1
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'stage_import_file'),
  'authoritative stage_import_file command exists'
);

select ok(
  (select p.prosecdef
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'stage_import_file'),
  'stage_import_file remains SECURITY DEFINER'
);

select ok(
  (select 'search_path=pg_catalog, public' = any(coalesce(p.proconfig, array[]::text[]))
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'stage_import_file'),
  'stage_import_file locks its search_path'
);

select ok(
  (select position('from public.import_rows ir' in lower(pg_get_functiondef(p.oid))) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'stage_import_file'),
  'import_rows is explicitly aliased'
);

select ok(
  (select position('where ir.batch_id = v_batch_id' in lower(pg_get_functiondef(p.oid))) > 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'stage_import_file'),
  'batch_id predicate is explicitly qualified'
);

select ok(
  (select position('where batch_id = v_batch_id' in lower(pg_get_functiondef(p.oid))) = 0
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'stage_import_file'),
  'ambiguous unqualified batch_id predicate is absent'
);

select ok(
  (select has_function_privilege('anon', 'public.stage_import_file(text,text,jsonb,text)', 'EXECUTE') = false
          and has_function_privilege('authenticated', 'public.stage_import_file(text,text,jsonb,text)', 'EXECUTE') = true),
  'execution remains restricted to authenticated callers'
);

select * from finish();
rollback;
