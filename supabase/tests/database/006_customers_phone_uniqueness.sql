begin;
set constraints all immediate;
select plan(11);

select ok(to_regclass('public.customers') is not null,'customers table exists');
select has_function('public','normalize_phone',ARRAY['text'],'phone normalization function exists');
select ok((select prokind='f' and provolatile='i' from pg_proc where oid='public.normalize_phone(text)'::regprocedure),'phone normalization is immutable');
select ok((select relrowsecurity from pg_class where oid='public.customers'::regclass),'customers has RLS enabled');
select ok(exists(select 1 from pg_indexes where schemaname='public' and tablename='customers' and indexname='uq_customers_normalized_phone' and indexdef like '%UNIQUE%'),'normalized phone has a unique index');
select ok(has_table_privilege('authenticated','public.customers','SELECT'),'authenticated has customer SELECT');
select ok(not has_table_privilege('authenticated','public.customers','INSERT'),'authenticated cannot directly insert customers');
select ok(not has_table_privilege('authenticated','public.customers','UPDATE'),'authenticated cannot directly update customers');
select ok(not has_table_privilege('authenticated','public.customers','DELETE'),'authenticated cannot directly delete customers');
select is(public.normalize_phone(' +971 50-123 (4567) '),'+971501234567','formats normalize to the canonical digits/+ representation');
select is(public.normalize_phone('00971 50 123 4567'),'+971501234567','00-prefixed international format normalizes to + representation');

select * from finish();
rollback;
