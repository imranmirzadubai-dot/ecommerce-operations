begin;

-- P4-T087: Admin permission boundary.
-- This task verifies the existing Admin-only administrative controls and the
-- shared operational command boundary without inventing additional permissions.
select plan(10);

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() <> ''admin''%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_profile'), 'create_profile requires the Admin application role');

select ok((select pg_get_functiondef(p.oid) like '%public.app_role() <> ''admin''%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='set_profile_active'), 'set_profile_active requires the Admin application role');

select ok(has_function_privilege('authenticated','public.create_profile(uuid,text,text)','execute'), 'authenticated role can reach create_profile function boundary');
select ok(has_function_privilege('anon','public.create_profile(uuid,text,text)','execute') = false, 'anonymous callers cannot execute create_profile');
select ok(has_function_privilege('authenticated','public.set_profile_active(uuid,boolean)','execute'), 'authenticated role can reach set_profile_active function boundary');
select ok(has_function_privilege('anon','public.set_profile_active(uuid,boolean)','execute') = false, 'anonymous callers cannot execute set_profile_active');

select ok((select count(*) = 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_admin_select' and cmd='SELECT'), 'Admin profile visibility is protected by the dedicated Admin SELECT policy');
select ok((select pg_get_expr(polqual, polrelid) like '%public.app_role() = ''admin''%'
  from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='profiles' and p.polname='profiles_admin_select'), 'Admin profile SELECT policy requires Admin role');

select ok((select count(*)=0 from information_schema.role_table_grants where grantee='authenticated' and table_schema='public' and privilege_type in ('INSERT','UPDATE','DELETE')), 'Admin/browser access has no direct table-write privilege');
select ok(has_function_privilege('authenticated','public.create_order(text,text,text,text,numeric,jsonb,text,text)','execute'), 'Admin retains access to the shared protected operational command boundary');

select * from finish();
rollback;
