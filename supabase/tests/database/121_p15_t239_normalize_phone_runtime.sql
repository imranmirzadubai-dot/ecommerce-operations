-- P15-T239: regression guard for the PostgreSQL UPDATE/LATERAL execution defect.
-- The phone-normalization implementation must correlate the lateral calculation
-- through a separate source-row alias; referencing the UPDATE target alias from
-- the lateral subquery fails at runtime on PostgreSQL 17.
begin;

select plan(4);

select ok(
  position('from public.import_rows source_row' in lower(pg_get_functiondef(p.oid))) > 0,
  'phone normalization uses a separate source-row alias'
)
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='normalize_import_phone_fields';

select ok(
  position('cross join lateral' in lower(pg_get_functiondef(p.oid))) > 0,
  'phone normalization retains the lateral calculation'
)
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='normalize_import_phone_fields';

select ok(
  position('where r.id = source_row.id' in lower(pg_get_functiondef(p.oid))) > 0,
  'phone normalization correlates the target row to the source-row alias'
)
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='normalize_import_phone_fields';

select ok(
  position('from lateral (' in lower(pg_get_functiondef(p.oid))) = 0,
  'phone normalization does not reference the update target directly from lateral'
)
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='normalize_import_phone_fields';

select * from finish();
rollback;
