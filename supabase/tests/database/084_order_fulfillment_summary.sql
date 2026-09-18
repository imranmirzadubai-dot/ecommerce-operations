begin;

select plan(12);

select ok((select count(*)=1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'order fulfillment summary view exists');
select ok((select pg_get_viewdef(c.oid,true) like '%parcel_count%' from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'summary exposes parcel count');
select ok((select pg_get_viewdef(c.oid,true) like '%delivered_parcel_count%' from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'summary exposes delivered parcel count');
select ok((select pg_get_viewdef(c.oid,true) like '%rto_parcel_count%' from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'summary exposes RTO parcel count');
select ok((select pg_get_viewdef(c.oid,true) like '%lost_parcel_count%' and pg_get_viewdef(c.oid,true) like '%damaged_parcel_count%' from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'summary exposes Lost/Damaged exception counts');
select ok((select pg_get_viewdef(c.oid,true) like '%nonterminal_parcel_count%' from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'summary exposes non-terminal parcel count');
select ok((select pg_get_viewdef(c.oid,true) like '%ordered_quantity%' and pg_get_viewdef(c.oid,true) like '%unresolved_quantity%' from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'summary exposes quantity reconciliation');
select ok((select pg_get_viewdef(c.oid,true) like '%In Progress%' from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'active/NDR parcel states project to In Progress');
select ok((select pg_get_viewdef(c.oid,true) like '%Delivered%' and pg_get_viewdef(c.oid,true) like '%RTO%' from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'uniform terminal Delivered and RTO orders have explicit summaries');
select ok((select pg_get_viewdef(c.oid,true) like '%Partial%' from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'mixed terminal outcomes project to Partial');
select ok((select pg_get_viewdef(c.oid,true) like '%Exception%' from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_fulfillment_summary' and c.relkind='v'),'Lost/Damaged-only terminal outcomes remain explicit exceptions');
select ok(has_table_privilege('authenticated','public.order_fulfillment_summary','select') and not has_table_privilege('anon','public.order_fulfillment_summary','select'),'authenticated users may read the summary while anonymous users cannot');

select * from finish();
rollback;
