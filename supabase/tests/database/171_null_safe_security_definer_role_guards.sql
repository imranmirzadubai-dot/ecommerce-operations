begin;

-- P17: authorization guards must fail closed when app_role() resolves to NULL.
select plan(5);

select ok((
  select count(*) = 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and pg_get_functiondef(p.oid) ~* 'public\.app_role\(\)\s*(<>|!=)\s*''admin'''
), 'no SECURITY DEFINER function retains a NULL-sensitive admin comparison');

select ok((
  select count(*) = 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and pg_get_functiondef(p.oid) ~* 'public\.app_role\(\)\s+not\s+in\s*\('
), 'no SECURITY DEFINER function retains a NULL-sensitive role allowlist');

select ok((
  select pg_get_functiondef(p.oid) ~* 'public\.app_role\(\)\s+is\s+distinct\s+from\s+''admin'''
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'create_profile' and p.prosecdef
), 'create_profile rejects NULL and non-admin roles');

select ok((
  select pg_get_functiondef(p.oid) ~* 'public\.app_role\(\)\s+is\s+distinct\s+from\s+''admin'''
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'set_profile_active' and p.prosecdef
), 'set_profile_active rejects NULL and non-admin roles');

select ok((
  select count(*) > 0
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and pg_get_functiondef(p.oid) ~* 'public\.app_role\(\)\s+is\s+null\s+or\s+public\.app_role\(\)\s+not\s+in\s*\('
), 'operational role allowlists explicitly reject a NULL role');

select * from finish();
rollback;
