begin;
select plan(12);

select ok(to_regclass('public.profiles') is not null,'profiles table exists');
select ok((select a.attnotnull from pg_attribute a where a.attrelid='public.profiles'::regclass and a.attname='id' and not a.attisdropped),'profile id is NOT NULL');
select ok((select a.atttypid='uuid'::regtype from pg_attribute a where a.attrelid='public.profiles'::regclass and a.attname='id' and not a.attisdropped),'profile id is uuid');
select ok((select a.attnotnull from pg_attribute a where a.attrelid='public.profiles'::regclass and a.attname='role' and not a.attisdropped),'role is NOT NULL');
select ok((select a.attnotnull from pg_attribute a where a.attrelid='public.profiles'::regclass and a.attname='active' and not a.attisdropped),'active is NOT NULL');
select ok((select pg_get_expr(d.adbin,d.adrelid) in ('true','true::boolean') from pg_attrdef d join pg_attribute a on a.attrelid=d.adrelid and a.attnum=d.adnum where d.adrelid='public.profiles'::regclass and a.attname='active'),'active defaults to true');
select ok(exists(
  select 1 from pg_constraint c
  where c.conrelid='public.profiles'::regclass
    and c.contype='c'
    and pg_get_constraintdef(c.oid) like '%sales%operations%admin%'
),'role is constrained to the three application roles');
select ok((select relrowsecurity from pg_class where oid='public.profiles'::regclass),'profiles has RLS enabled');
select ok(exists(
  select 1 from pg_policies
  where schemaname='public' and tablename='profiles'
    and policyname='profiles_self_select'
    and cmd='SELECT'
    and roles='{authenticated}'
    and qual like '%auth.uid()%'
),'profiles has authenticated self-select policy');
select ok(has_function('public','app_role',ARRAY[]::text[]),'app_role function exists');
select ok(exists(
  select 1 from pg_proc p
  where p.oid='public.app_role()'::regprocedure
    and p.prosecdef
    and p.proconfig @> array['search_path=pg_catalog, public']
),'app_role is SECURITY DEFINER with controlled search_path');
select ok(not has_table_privilege('authenticated','public.profiles','INSERT')
       and not has_table_privilege('authenticated','public.profiles','UPDATE')
       and not has_table_privilege('authenticated','public.profiles','DELETE'),'authenticated has no direct profile write privileges');

select * from finish();
rollback;
