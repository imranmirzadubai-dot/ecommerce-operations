begin;

select plan(11);

select has_index(
  'public',
  'shippers',
  'uq_shippers_courier_name_normalized',
  'normalized courier-name uniqueness index exists'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'shippers'
      and indexname = 'uq_shippers_courier_name_normalized'
      and indexdef ilike '%unique index%'
      and indexdef ilike '%lower(btrim(name))%'
  ),
  'normalized courier-name index uses lower(btrim(name))'
);

select has_column('public', 'shippers', 'courier_code', 'courier code remains on existing courier master');
select has_column('public', 'shippers', 'active', 'active state remains on existing courier master');
select has_column('public', 'shippers', 'contact_name', 'contact name remains available');
select has_column('public', 'shippers', 'contact_phone', 'contact phone remains available');
select has_column('public', 'shippers', 'contact_email', 'contact email remains available');
select has_column('public', 'shippers', 'address', 'address remains available');
select has_column('public', 'shippers', 'notes', 'notes remains available');

select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'shippers'
      and c.contype = 'u'
  ) or exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'shippers'
      and indexdef ilike '%unique%'
  ),
  'courier master retains uniqueness enforcement'
);

select ok(
  not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'shipper'
  ),
  'no replacement singular shipper table exists'
);

select finish();
rollback;
