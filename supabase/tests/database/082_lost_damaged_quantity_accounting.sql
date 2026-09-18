begin;

select plan(11);

select ok(
  (select count(*) = 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_terminal_reconciliation' and c.relkind = 'v'),
  'terminal quantity reconciliation view exists'
);
select ok((select pg_get_viewdef(c.oid, true) like '%delivered_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_terminal_reconciliation' and c.relkind = 'v'), 'view exposes delivered quantity');
select ok((select pg_get_viewdef(c.oid, true) like '%rto_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_terminal_reconciliation' and c.relkind = 'v'), 'view exposes RTO quantity');
select ok((select pg_get_viewdef(c.oid, true) like '%lost_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_terminal_reconciliation' and c.relkind = 'v'), 'view exposes Lost quantity');
select ok((select pg_get_viewdef(c.oid, true) like '%damaged_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_terminal_reconciliation' and c.relkind = 'v'), 'view exposes Damaged quantity');
select ok((select pg_get_viewdef(c.oid, true) like '%unresolved_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_terminal_reconciliation' and c.relkind = 'v'), 'view exposes unresolved quantity');
select ok((select pg_get_viewdef(c.oid, true) like '%accounted_quantity%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_terminal_reconciliation' and c.relkind = 'v'), 'view exposes accounted terminal quantity');
select ok((select pg_get_viewdef(c.oid, true) like '%has_lost_or_damaged%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_terminal_reconciliation' and c.relkind = 'v'), 'view exposes Lost/Damaged exception indicator');
select ok((select pg_get_viewdef(c.oid, true) like '%terminal_quantity_within_ordered%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_terminal_reconciliation' and c.relkind = 'v'), 'view exposes ordered-quantity invariant check');
select ok((select pg_get_viewdef(c.oid, true) like '%p.state = ''Lost''%' and pg_get_viewdef(c.oid, true) like '%p.state = ''Damaged''%' from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'order_item_terminal_reconciliation' and c.relkind = 'v'), 'Lost and Damaged quantities are derived from authoritative parcel states');
select ok(has_table_privilege('authenticated', 'public.order_item_terminal_reconciliation', 'select') and not has_table_privilege('anon', 'public.order_item_terminal_reconciliation', 'select'), 'authenticated users may read the reconciliation while anonymous users cannot');

select * from finish();
rollback;
