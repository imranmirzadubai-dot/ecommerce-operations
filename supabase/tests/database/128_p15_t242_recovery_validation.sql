-- P15-T242 — Recovery validation harness
-- Read-only validation intended for an isolated restore target.
-- This does NOT create, restore, export, or mutate production data.

do $$
declare
  v_missing text[];
  v_table text;
  v_count integer;
begin
  select array_agg(x.name order by x.name)
    into v_missing
  from (
    values
      ('profiles'), ('customers'), ('orders'), ('order_items'),
      ('order_events'), ('parcels'), ('parcel_items'),
      ('delivery_outcomes'), ('cod_obligations'), ('cod_receipts'),
      ('financial_adjustments'), ('invoice_records'),
      ('import_batches'), ('import_rows'), ('audit_logs'),
      ('command_idempotency')
  ) as x(name)
  where to_regclass('public.' || x.name) is null;

  if v_missing is not null then
    raise exception 'P15-T242 missing required application tables: %', array_to_string(v_missing, ', ');
  end if;

  foreach v_table in array array[
    'profiles','customers','orders','order_items','order_events',
    'parcels','parcel_items','delivery_outcomes','cod_obligations',
    'cod_receipts','financial_adjustments','invoice_records',
    'import_batches','import_rows','audit_logs','command_idempotency'
  ]
  loop
    select count(*) into v_count
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = v_table
      and c.contype in ('p','u','f');

    if v_count = 0 then
      raise exception 'P15-T242 table % has no PK/UNIQUE/FK constraints', v_table;
    end if;
  end loop;
end $$;

-- Representative row counts. These are evidence outputs, not fixed expectations.
select jsonb_build_object(
  'profiles', (select count(*) from public.profiles),
  'customers', (select count(*) from public.customers),
  'orders', (select count(*) from public.orders),
  'order_items', (select count(*) from public.order_items),
  'order_events', (select count(*) from public.order_events),
  'parcels', (select count(*) from public.parcels),
  'parcel_items', (select count(*) from public.parcel_items),
  'delivery_outcomes', (select count(*) from public.delivery_outcomes),
  'cod_obligations', (select count(*) from public.cod_obligations),
  'cod_receipts', (select count(*) from public.cod_receipts),
  'financial_adjustments', (select count(*) from public.financial_adjustments),
  'invoice_records', (select count(*) from public.invoice_records),
  'import_batches', (select count(*) from public.import_batches),
  'import_rows', (select count(*) from public.import_rows),
  'audit_logs', (select count(*) from public.audit_logs),
  'command_idempotency', (select count(*) from public.command_idempotency)
) as representative_row_counts;

-- Required access-boundary evidence for restored application data.
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'profiles','customers','orders','order_items','order_events',
    'parcels','parcel_items','delivery_outcomes','cod_obligations',
    'cod_receipts','financial_adjustments','invoice_records',
    'import_batches','import_rows','audit_logs','command_idempotency'
  )
order by c.relname;

-- Reporting-view security evidence.
select
  c.relname as view_name,
  coalesce(c.reloptions, '{}') as reloptions
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'v'
  and c.relname like 'report_%'
order by c.relname;
