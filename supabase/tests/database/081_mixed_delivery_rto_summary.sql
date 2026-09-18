begin;

select plan(10);

select ok(
  (select count(*) = 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_delivery_rto_summary' and c.relkind = 'v'),
  'order-level Delivered/RTO summary view exists'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%ordered_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_delivery_rto_summary' and c.relkind = 'v'),
  'summary exposes ordered quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%delivered_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_delivery_rto_summary' and c.relkind = 'v'),
  'summary exposes delivered quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%rto_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_delivery_rto_summary' and c.relkind = 'v'),
  'summary exposes RTO quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%unresolved_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_delivery_rto_summary' and c.relkind = 'v'),
  'summary exposes unresolved quantity'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%is_mixed_delivered_rto%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_delivery_rto_summary' and c.relkind = 'v'),
  'summary exposes mixed Delivered/RTO indicator'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%is_partially_resolved%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_delivery_rto_summary' and c.relkind = 'v'),
  'summary exposes partial-resolution indicator'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%order_item_delivery_reconciliation%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_delivery_rto_summary' and c.relkind = 'v'),
  'summary derives from the canonical item-level reconciliation view'
);

select ok(
  (select pg_get_viewdef(c.oid, true) like '%sum(r.delivered_quantity)%' and pg_get_viewdef(c.oid, true) like '%sum(r.rto_quantity)%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_delivery_rto_summary' and c.relkind = 'v'),
  'summary aggregates Delivered and RTO quantities across order items'
);

select ok(
  has_table_privilege('authenticated', 'public.order_delivery_rto_summary', 'select')
  and not has_table_privilege('anon', 'public.order_delivery_rto_summary', 'select'),
  'authenticated users may read the summary while anonymous users cannot'
);

select * from finish();
rollback;
