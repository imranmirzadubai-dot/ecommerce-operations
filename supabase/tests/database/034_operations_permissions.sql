begin;

-- P4-T086: Operations permission boundary.
-- This task tests the role matrix already established by the command layer;
-- it does not invent additional business permissions.
select plan(10);

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_order'), 'Operations is included in the protected create-order role boundary');

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='confirm_order'), 'Operations is included in the protected confirm-order role boundary');

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='cancel_order'), 'Operations is included in the protected cancel-order role boundary');

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='cancel_parcel'), 'Operations is included in the protected cancel-parcel role boundary');

select ok(has_function_privilege('authenticated','public.create_order(text,text,text,text,numeric,jsonb,text,text)','execute'), 'authenticated role can execute create_order command');
select ok(has_function_privilege('authenticated','public.confirm_order(uuid,text)','execute'), 'authenticated role can execute confirm_order command');
select ok(has_function_privilege('authenticated','public.cancel_order(uuid,text)','execute'), 'authenticated role can execute cancel_order command');
select ok(has_function_privilege('authenticated','public.cancel_parcel(uuid,text)','execute'), 'authenticated role can execute cancel-parcel command');

select ok(has_function_privilege('authenticated','public.create_profile(uuid,text,text)','execute'), 'administrative profile-link command remains behind authenticated boundary');
select ok((select count(*)=0 from information_schema.role_table_grants where grantee='authenticated' and table_schema='public' and privilege_type in ('INSERT','UPDATE','DELETE')), 'Operations/browser access has no direct table-write privilege');

select * from finish();
rollback;
