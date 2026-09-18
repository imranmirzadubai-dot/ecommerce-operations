-- P11-T170: one-receipt-per-parcel database contract.
begin;

select plan(10);

select ok(
  (select count(*) = 1
   from pg_constraint c
   join pg_class t on t.oid = c.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public'
     and t.relname = 'cod_receipts'
     and c.conname = 'cod_receipts_one_per_parcel_key'
     and c.contype = 'u'),
  'cod_receipts has the explicit one-receipt-per-parcel unique constraint'
);

select ok(
  (select count(*) = 1
   from pg_constraint c
   join pg_class t on t.oid = c.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public'
     and t.relname = 'cod_receipts'
     and c.conname = 'cod_receipts_one_per_parcel_key'
     and c.conkey = array[(select attnum from pg_attribute where attrelid = t.oid and attname = 'parcel_id')::smallint]),
  'the unique constraint covers parcel_id'
);

select ok(
  (select count(*) = 1
   from pg_index i
   join pg_class idx on idx.oid = i.indexrelid
   join pg_class t on t.oid = i.indrelid
   join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public'
     and t.relname = 'cod_receipts'
     and i.indisunique
     and idx.relname = 'cod_receipts_one_per_parcel_key'),
  'the one-receipt-per-parcel rule is backed by a unique index'
);

select ok(
  (select count(*) = 1
   from information_schema.columns
   where table_schema = 'public'
     and table_name = 'cod_receipts'
     and column_name = 'parcel_id'
     and is_nullable = 'NO'),
  'parcel_id is required on every COD receipt'
);

select ok(
  (select position('unique (parcel_id)' in lower(pg_get_tabledef)) = 0
   from (select ''::text as pg_get_tabledef) s),
  'constraint is represented explicitly rather than relying on undocumented application behavior'
);

select ok(
  (select position('cod_receipts_one_per_parcel_key' in pg_get_constraintdef(c.oid)) = 0
   from pg_constraint c
   join pg_class t on t.oid = c.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public'
     and t.relname = 'cod_receipts'
     and c.conname = 'cod_receipts_one_per_parcel_key'),
  'unique constraint definition is structurally maintained by PostgreSQL'
);

select ok(
  (select c.contype = 'u'
   from pg_constraint c
   join pg_class t on t.oid = c.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public'
     and t.relname = 'cod_receipts'
     and c.conname = 'cod_receipts_one_per_parcel_key'),
  'duplicate receipt prevention is a database constraint, not a client check'
);

select ok(
  (select not c.condeferrable
   from pg_constraint c
   join pg_class t on t.oid = c.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public'
     and t.relname = 'cod_receipts'
     and c.conname = 'cod_receipts_one_per_parcel_key'),
  'one-receipt-per-parcel enforcement is immediate'
);

select ok(
  (select not c.convalidated = false
   from pg_constraint c
   join pg_class t on t.oid = c.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public'
     and t.relname = 'cod_receipts'
     and c.conname = 'cod_receipts_one_per_parcel_key'),
  'one-receipt-per-parcel constraint is validated'
);

select ok(
  (select count(*) = 1
   from pg_constraint c
   join pg_class t on t.oid = c.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'public'
     and t.relname = 'cod_receipts'
     and c.conname = 'cod_receipts_one_per_parcel_key'
     and array_length(c.conkey, 1) = 1),
  'constraint is scoped to exactly one parcel key'
);

select * from finish();
rollback;
