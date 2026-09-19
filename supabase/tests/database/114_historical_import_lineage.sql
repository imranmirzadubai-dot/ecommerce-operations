-- P12-T195 regression coverage for durable historical source lineage.
begin;

select plan(13);

select ok((select count(*) = 4
  from information_schema.columns
  where table_schema='public'
    and table_name='orders'
    and column_name in ('historical_import_batch_id','historical_import_source_row_number','historical_import_source_record_id','historical_import_source_identity')),
  'orders retain the four historical import lineage fields');

select ok((select count(*) = 1
  from pg_constraint c
  join pg_class t on t.oid=c.conrelid
  join pg_namespace n on n.oid=t.relnamespace
  where n.nspname='public' and t.relname='orders'
    and c.conname='orders_historical_import_batch_fk'
    and c.contype='f'),
  'historical order lineage has a foreign key to import_batches');

select ok((select count(*) = 1
  from pg_constraint c
  join pg_class t on t.oid=c.conrelid
  join pg_namespace n on n.oid=t.relnamespace
  where n.nspname='public' and t.relname='orders'
    and c.conname='orders_historical_import_lineage_check'
    and c.contype='c'),
  'historical order lineage fields have an all-or-none integrity check');

select ok((select count(*) = 1
  from pg_indexes
  where schemaname='public'
    and tablename='orders'
    and indexname='uq_orders_historical_import_batch_row'),
  'historical batch and source row are uniquely retained per imported order');

select ok((select count(*) = 1
  from pg_indexes
  where schemaname='public'
    and tablename='orders'
    and indexname='idx_orders_historical_import_source_identity'),
  'historical source identity is indexed for lineage lookup');

select ok((select count(*) = 1
  from pg_trigger tg
  join pg_class t on t.oid=tg.tgrelid
  join pg_namespace n on n.oid=t.relnamespace
  where n.nspname='public' and t.relname='order_events'
    and tg.tgname='trg_retain_historical_import_lineage'
    and not tg.tgisinternal),
  'Historical Import events invoke the lineage retention trigger');

select ok((select position('historical_import_batch_id' in lower(pg_get_functiondef(p.oid))) > 0
              and position('historical_import_source_row_number' in lower(pg_get_functiondef(p.oid))) > 0
              and position('historical_import_source_record_id' in lower(pg_get_functiondef(p.oid))) > 0
              and position('historical_import_source_identity' in lower(pg_get_functiondef(p.oid))) > 0
           from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.proname='retain_historical_import_lineage'),
  'lineage trigger persists batch, source row, source record, and source identity');

select ok((select position('public.import_rows' in lower(pg_get_functiondef(p.oid))) > 0
              and position('source_row_number' in lower(pg_get_functiondef(p.oid))) > 0
              and position('source_identity' in lower(pg_get_functiondef(p.oid))) > 0
           from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.proname='retain_historical_import_lineage'),
  'lineage trigger validates against the retained staged source row');

select ok((select position('set status = ''imported''' in lower(pg_get_functiondef(p.oid))) > 0
           from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.proname='retain_historical_import_lineage'),
  'source row is marked Imported after successful production lineage retention');

select ok((select position('is distinct from v_source_record_id' in lower(pg_get_functiondef(p.oid))) > 0
              and position('is distinct from v_source_identity' in lower(pg_get_functiondef(p.oid))) > 0
           from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.proname='retain_historical_import_lineage'),
  'source record and identity mismatches are rejected');

select ok((select position('already has conflicting historical import lineage' in lower(pg_get_functiondef(p.oid))) > 0
           from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.proname='retain_historical_import_lineage'),
  'existing conflicting order lineage is rejected');

select ok((select position('on delete restrict' in lower(pg_get_constraintdef(c.oid))) > 0
           from pg_constraint c
           join pg_class t on t.oid=c.conrelid
           join pg_namespace n on n.oid=t.relnamespace
           where n.nspname='public' and t.relname='orders'
             and c.conname='orders_historical_import_batch_fk'),
  'historical batch lineage cannot be orphaned by deleting its batch');

select ok((select position('security definer' in lower(pg_get_functiondef(p.oid))) > 0
              and position('search_path = pg_catalog, public' in lower(pg_get_functiondef(p.oid))) > 0
           from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.proname='retain_historical_import_lineage'),
  'lineage trigger function uses the repository security-definer search-path contract');

select * from finish();
rollback;
