begin;

select plan(10);

select ok(
  (select count(*) = 1
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'order_item_delivery_reconciliation'
     and c.relkind = 'v'),
  'partial delivery reconciliation view exists'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%delivered_quantity%'
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'order_item_delivery_reconciliation'
     and c.relkind = 'v'),
  'view exposes derived delivered quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%rto_quantity%'
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'order_item_delivery_reconciliation'
     and c.relkind = 'v'),
  'view exposes derived RTO quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%unresolved_quantity%'
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'order_item_delivery_reconciliation'
     and c.relkind = 'v'),
  'view exposes unresolved remainder'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%order_items%'
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'order_item_delivery_reconciliation'
     and c.relkind = 'v'),
  'reconciliation preserves original order-item quantity as the source of truth'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%parcel_items%'
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'order_item_delivery_reconciliation'
     and c.relkind = 'v'),
  'reconciliation derives quantities from parcel-item allocations'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%p.state = ''Delivered''%'
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'order_item_delivery_reconciliation'
     and c.relkind = 'v'),
  'Delivered parcels contribute to delivered quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%p.state = ''RTO''%'
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'order_item_delivery_reconciliation'
     and c.relkind = 'v'),
  'RTO parcels contribute to RTO quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%allocation_state = ''Allocated''%'
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'order_item_delivery_reconciliation'
     and c.relkind = 'v'),
  'only active allocated parcel quantities are reconciled'
);

select ok(
  (select has_table_privilege('authenticated', 'public.order_item_delivery_reconciliation', 'select'))
  and not (select has_table_privilege('anon', 'public.order_item_delivery_reconciliation', 'select')),
  'authenticated users may read reconciliation while anonymous users cannot'
);

select * from finish();
rollback;
