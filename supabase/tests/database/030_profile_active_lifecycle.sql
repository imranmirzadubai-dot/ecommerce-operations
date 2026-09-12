-- P4-T082 executable structural/security checks for application-profile lifecycle.
begin;

select plan(10);

select ok((select count(*) = 1 from pg_proc where pronamespace = 'public'::regnamespace and proname = 'set_profile_active' and proargtypes = '2950 16'::oidvector), 'set_profile_active command exists with expected signature');
select ok((select prosecdef from pg_proc where pronamespace = 'public'::regnamespace and proname = 'set_profile_active' and proargtypes = '2950 16'::oidvector), 'set_profile_active is SECURITY DEFINER');
select ok((select proconfig @> array['search_path=pg_catalog, public'] from pg_proc where pronamespace = 'public'::regnamespace and proname = 'set_profile_active' and proargtypes = '2950 16'::oidvector), 'set_profile_active has controlled search_path');
select ok((select has_function_privilege('anon','public.set_profile_active(uuid,boolean)','execute') = false), 'anon cannot execute set_profile_active');
select ok((select has_function_privilege('authenticated','public.set_profile_active(uuid,boolean)','execute')), 'authenticated can reach the controlled lifecycle command boundary');
select ok((select pg_get_functiondef(p.oid) like '%public.app_role() <> ''admin''%' from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'set_profile_active' and p.proargtypes = '2950 16'::oidvector), 'lifecycle command requires an active Admin application role');
select ok((select pg_get_functiondef(p.oid) like '%update public.profiles%' and pg_get_functiondef(p.oid) like '%set active = p_active%' from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'set_profile_active' and p.proargtypes = '2950 16'::oidvector), 'lifecycle command updates only the application profile active state');
select ok((select pg_get_functiondef(p.oid) like '%profile_not_found%' from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'set_profile_active' and p.proargtypes = '2950 16'::oidvector), 'lifecycle command rejects an unknown profile');
select ok((select (not exists (select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='active' and is_nullable <> 'NO'))), 'profile active state remains NOT NULL');
select ok((select (select column_default from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='active') like 'true%'), 'new profiles default to active');

select * from finish();
rollback;
