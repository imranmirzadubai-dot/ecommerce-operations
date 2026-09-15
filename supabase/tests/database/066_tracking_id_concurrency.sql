begin;

-- P9-T145: concurrency regression coverage for globally unique tracking IDs.
-- PostgreSQL's unique index is the authoritative race-safe boundary: concurrent
-- transactions cannot commit two equal canonical tracking IDs. The dispatch
-- command must also use the same canonical validator rather than relying on UI checks.
select plan(12);

select ok(
  (select count(*) = 1
   from pg_indexes
   where schemaname='public'
     and tablename='parcels'
     and indexname='idx_parcels_normalized_tracking_id_unique'
     and indexdef like '%UNIQUE%'
     and indexdef like '%normalized_tracking_id%'),
  'normalized tracking ID has a database-enforced UNIQUE index'
);

select ok(
  (select indexdef like '%WHERE (normalized_tracking_id IS NOT NULL)%'
   from pg_indexes
   where schemaname='public'
     and indexname='idx_parcels_normalized_tracking_id_unique'),
  'tracking uniqueness is partial so null tracking IDs remain allowed'
);

select ok(
  (select indisunique
   from pg_index i
   join pg_class c on c.oid=i.indexrelid
   join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='idx_parcels_normalized_tracking_id_unique'),
  'tracking uniqueness is enforced by PostgreSQL rather than application state'
);

select ok(
  (select count(*) = 1
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public'
     and p.proname='normalize_tracking_id'
     and pg_get_function_identity_arguments(p.oid)='p_tracking_id text'
     and p.provolatile='i'),
  'tracking normalization is immutable and deterministic'
);

select is(public.normalize_tracking_id('  race-trk-001  '),'RACE-TRK-001','canonical key trims and normalizes case');

select ok(
  (select pg_get_functiondef(p.oid) like '%validate_unique_tracking_id%'
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='dispatch_parcel'),
  'dispatch uses the canonical server-side tracking validator'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%normalized_tracking_id=v_normalized_tracking_id%'
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='dispatch_parcel'),
  'dispatch writes the same normalized concurrency key used by the unique index'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%p.normalized_tracking_id = v_normalized%'
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='validate_unique_tracking_id'),
  'preflight validation checks the canonical uniqueness key'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%p.id <> p_parcel_id%'
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='validate_unique_tracking_id'),
  'validation excludes the current parcel from its own uniqueness check'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%raise exception%'
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='dispatch_parcel'),
  'dispatch retains transactional exception handling so a uniqueness race cannot partially commit'
);

select ok(
  (select count(*) = 0
   from information_schema.role_table_grants
   where grantee='authenticated'
     and table_schema='public'
     and table_name='parcels'
     and privilege_type in ('INSERT','UPDATE','DELETE')),
  'browser roles cannot bypass the race-safe command boundary with direct parcel writes'
);

select ok(
  (select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public']
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='validate_unique_tracking_id'),
  'tracking validator remains security-definer with pinned search_path'
);

select * from finish();
rollback;
