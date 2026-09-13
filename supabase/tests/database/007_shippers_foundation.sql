begin;
set constraints all immediate;

select plan(10);

select ok(to_regclass('public.shippers') is not null, 'shippers table exists');
select ok((select data_type = 'uuid' from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='id'), 'shipper id is uuid');
select ok((select is_nullable = 'NO' from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='name'), 'shipper name is required');
select ok((select is_nullable = 'NO' from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='active'), 'shipper active is required');
select ok((select column_default like '%true%' from information_schema.columns where table_schema='public' and table_name='shippers' and column_name='active'), 'shipper active defaults true');
select ok(exists(select 1 from pg_constraint c join pg_class r on r.oid=c.conrelid where r.oid='public.shippers'::regclass and c.contype='u' and pg_get_constraintdef(c.oid) like '%(name)%'), 'shipper name has unique constraint');
select ok((select relrowsecurity from pg_class where oid='public.shippers'::regclass), 'shippers has RLS enabled');
select ok(has_table_privilege('authenticated','public.shippers','select'), 'authenticated has shipper SELECT');
select ok(not has_table_privilege('authenticated','public.shippers','insert'), 'authenticated cannot insert shippers directly');
select ok(not has_table_privilege('authenticated','public.shippers','update') and not has_table_privilege('authenticated','public.shippers','delete'), 'authenticated cannot update or delete shippers directly');

select * from finish();
rollback;
