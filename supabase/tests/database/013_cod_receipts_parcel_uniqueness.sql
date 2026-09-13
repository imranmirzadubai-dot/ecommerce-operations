begin;

-- P3-T061: COD receipts must have at most one receipt per parcel.
select has_table_privilege('authenticated', 'public.cod_receipts', 'SELECT') as authenticated_select;
select has_table_privilege('authenticated', 'public.cod_receipts', 'INSERT') as authenticated_insert;
select has_table_privilege('authenticated', 'public.cod_receipts', 'UPDATE') as authenticated_update;
select has_table_privilege('authenticated', 'public.cod_receipts', 'DELETE') as authenticated_delete;

select exists (
  select 1
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public'
    and t.relname = 'cod_receipts'
    and c.contype = 'u'
    and pg_get_constraintdef(c.oid) = 'UNIQUE (parcel_id)'
) or exists (
  select 1
  from pg_indexes
  where schemaname = 'public'
    and tablename = 'cod_receipts'
    and indexdef ilike '%unique%parcel_id%'
) as parcel_unique;

select relrowsecurity as rls_enabled
from pg_class
where oid = 'public.cod_receipts'::regclass;

rollback;
