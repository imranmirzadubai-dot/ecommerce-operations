-- P4-T080 executable structural/security checks.
-- Behavioral creation is exercised through the authenticated Admin command path.
begin;

select plan(8);

select ok((select count(*) = 1 from pg_proc where pronamespace = 'public'::regnamespace and proname = 'create_profile' and proargtypes = '2950 25 25'::oidvector), 'create_profile command exists with expected signature');
select ok((select prosecdef from pg_proc where pronamespace = 'public'::regnamespace and proname = 'create_profile' and proargtypes = '2950 25 25'::oidvector), 'create_profile is SECURITY DEFINER');
select ok((select proconfig @> array['search_path=pg_catalog, public, auth'] from pg_proc where pronamespace = 'public'::regnamespace and proname = 'create_profile' and proargtypes = '2950 25 25'::oidvector), 'create_profile has controlled search_path');
select ok((select has_function_privilege('anon','public.create_profile(uuid,text,text)','execute') = false), 'anon cannot execute create_profile');
select ok((select has_function_privilege('authenticated','public.create_profile(uuid,text,text)','execute')), 'authenticated can reach the controlled command boundary');
select ok((select pg_get_functiondef(p.oid) like '%public.app_role() <> ''admin''%' from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'create_profile' and p.proargtypes = '2950 25 25'::oidvector), 'command requires an active Admin application role');
select ok((select pg_get_functiondef(p.oid) like '%from auth.users u%' and pg_get_functiondef(p.oid) like '%where u.id = p_user_id%' from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'create_profile' and p.proargtypes = '2950 25 25'::oidvector), 'profile links only to an existing auth.users identity');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.profiles (id, name, email, role, active)%' from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'create_profile' and p.proargtypes = '2950 25 25'::oidvector), 'command creates the linked application profile');

select * from finish();
rollback;
