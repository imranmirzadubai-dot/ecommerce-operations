-- P4-T083 administrator user controls: admin profile visibility and command boundaries.
begin;
select plan(8);
select ok((select count(*) = 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_admin_select' and cmd='SELECT' and roles = array['authenticated'::name]), 'admin profile SELECT policy exists');
select ok((select pg_get_expr(polqual, polrelid) like '%public.app_role() = ''admin''%' from pg_policy where polname='profiles_admin_select'), 'admin profile SELECT policy is restricted to active Admin role');
select ok((select has_table_privilege('authenticated','public.profiles','select')), 'authenticated role retains profile SELECT capability');
select ok((select has_table_privilege('authenticated','public.profiles','update') = false), 'browser cannot directly update profiles');
select ok((select has_function_privilege('authenticated','public.create_profile(uuid,text,text)','execute')), 'authenticated role can reach controlled profile-linking command');
select ok((select has_function_privilege('anon','public.create_profile(uuid,text,text)','execute') = false), 'anon cannot execute profile-linking command');
select ok((select has_function_privilege('authenticated','public.set_profile_active(uuid,boolean)','execute')), 'authenticated role can reach controlled lifecycle command');
select ok((select has_function_privilege('anon','public.set_profile_active(uuid,boolean)','execute') = false), 'anon cannot execute lifecycle command');
select * from finish();
rollback;
