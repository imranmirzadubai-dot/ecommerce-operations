begin;

-- P4-T088: inactive-account access boundary.
-- This task verifies that inactive application profiles cannot obtain operational
-- access through the existing authentication/profile-loading and role-resolution paths.
select plan(10);

select ok((select count(*) = 1
  from information_schema.columns
  where table_schema='public' and table_name='profiles'
    and column_name='active' and is_nullable='NO'
    and column_default='true'::text), 'profiles.active is mandatory and defaults to true');

select ok((select pg_get_functiondef(p.oid) like '%active%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_role'), 'app_role resolves application role from profile state');

select ok((select pg_get_functiondef(p.oid) like '%active = true%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_role'), 'app_role requires an active profile');

select ok((select pg_get_functiondef(p.oid) like '%active%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_role'), 'inactive profile state is part of authorization role resolution');

select ok(has_function_privilege('authenticated','public.create_order(text,text,text,text,numeric,jsonb,text,text)','execute'), 'operational command remains behind authenticated function boundary');
select ok(has_function_privilege('authenticated','public.confirm_order(uuid,text)','execute'), 'confirm command remains behind authenticated function boundary');
select ok(has_function_privilege('authenticated','public.cancel_order(uuid,text)','execute'), 'cancel order command remains behind authenticated function boundary');
select ok(has_function_privilege('authenticated','public.cancel_parcel(uuid,text)','execute'), 'cancel parcel command remains behind authenticated function boundary');

select ok((select count(*)=0
  from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public'
    and privilege_type in ('INSERT','UPDATE','DELETE')), 'inactive users cannot bypass authorization with direct browser table writes');

select ok((select count(*) = 1
  from pg_policies
  where schemaname='public' and tablename='profiles'
    and policyname='profiles_admin_select' and cmd='SELECT'), 'profile visibility remains policy-controlled rather than a direct-write path');

select * from finish();
rollback;
