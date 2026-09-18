begin;

select plan(10);

select ok(
  (select count(*) = 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_rto_reconciliation' and c.relkind = 'v'),
  'partial RTO reconciliation view exists'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%allocated_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_rto_reconciliation' and c.relkind = 'v'),
  'view exposes derived allocated quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%rto_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_rto_reconciliation' and c.relkind = 'v'),
  'view exposes derived RTO quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%non_rto_allocated_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_rto_reconciliation' and c.relkind = 'v'),
  'view exposes remaining non-RTO allocated quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%is_partial_rto%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_rto_reconciliation' and c.relkind = 'v'),
  'view exposes partial RTO indicator'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%order_items%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_rto_reconciliation' and c.relkind = 'v'),
  'reconciliation preserves original order-item quantity as source context'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%parcel_items%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_rto_reconciliation' and c.relkind = 'v'),
  'reconciliation derives quantities from parcel-item allocations'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%p.state = ''RTO''%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_rto_reconciliation' and c.relkind = 'v'),
  'RTO parcels contribute to RTO quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%allocation_state = ''Allocated''%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_rto_reconciliation' and c.relkind = 'v'),
  'only active allocated parcel quantities are reconciled'
);

select ok(
  (select has_table_privilege('authenticated', 'public.order_item_rto_reconciliation', 'select'))
  and not (select has_table_privilege('anon', 'public.order_item_rto_reconciliation', 'select')),
  'authenticated users may read reconciliation while anonymous users cannot'
);

select * from finish();
rollback;
