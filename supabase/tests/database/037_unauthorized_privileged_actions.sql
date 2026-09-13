begin;

-- P4-T089: unauthorized privileged action boundary.
-- Verify privileged administrative commands cannot be reached by non-admin roles,
-- while shared operational commands retain their approved role boundary.
select plan(12);

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() <> ''admin''%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_profile'), 'create_profile rejects non-Admin application roles');

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() <> ''admin''%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='set_profile_active'), 'set_profile_active rejects non-Admin application roles');

select ok(has_function_privilege('anon','public.create_profile(uuid,text,text)','execute') = false, 'anonymous callers cannot execute create_profile');
select ok(has_function_privilege('anon','public.set_profile_active(uuid,boolean)','execute') = false, 'anonymous callers cannot execute set_profile_active');

select ok((select count(*)=0
  from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public'
    and privilege_type in ('INSERT','UPDATE','DELETE')), 'authenticated browser role has no direct table-write privilege');

select ok((select pg_get_functiondef(p.oid) like '%auth.uid() is null%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'create_order rejects unauthenticated callers');

select ok((select pg_get_functiondef(p.oid) like '%auth.uid() is null%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirm_order rejects unauthenticated callers');

select ok((select pg_get_functiondef(p.oid) like '%auth.uid() is null%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='cancel_order'), 'cancel_order rejects unauthenticated callers');

select ok((select pg_get_functiondef(p.oid) like '%auth.uid() is null%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='cancel_parcel'), 'cancel_parcel rejects unauthenticated callers');

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'create_order rejects roles outside the approved application-role set');

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'confirm_order rejects roles outside the approved application-role set');

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='cancel_order'), 'cancel_order rejects roles outside the approved application-role set');

select * from finish();
rollback;
