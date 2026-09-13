begin;

select exists (select 1 from pg_class where relname = 'order_items') as table_exists;
select exists (select 1 from pg_constraint c join pg_class t on t.oid=c.conrelid where t.relname='order_items' and c.contype='p') as primary_key_exists;
select exists (select 1 from pg_constraint c join pg_class t on t.oid=c.conrelid where t.relname='order_items' and c.conname='order_items_order_id_fkey') as order_fk_exists;
select exists (select 1 from pg_constraint c join pg_class t on t.oid=c.conrelid where t.relname='order_items' and c.conname='order_items_line_no_check') as positive_line_no;
select exists (select 1 from pg_constraint c join pg_class t on t.oid=c.conrelid where t.relname='order_items' and c.conname='order_items_quantity_check') as positive_quantity;
select exists (select 1 from pg_constraint c join pg_class t on t.oid=c.conrelid where t.relname='order_items' and c.conname='order_items_order_id_line_no_key') as unique_order_line;
select relrowsecurity from pg_class where relname='order_items' as rls_enabled;
select has_table_privilege('authenticated','public.order_items','SELECT') as authenticated_select;
select not has_table_privilege('authenticated','public.order_items','INSERT') as authenticated_insert_denied;
select not has_table_privilege('authenticated','public.order_items','UPDATE') as authenticated_update_denied;
select not has_table_privilege('authenticated','public.order_items','DELETE') as authenticated_delete_denied;

rollback;
