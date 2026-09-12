begin;
select has_table_privilege('authenticated', 'public.orders', 'SELECT') as authenticated_select;
select not has_table_privilege('authenticated', 'public.orders', 'INSERT') as authenticated_insert_denied;
select not has_table_privilege('authenticated', 'public.orders', 'UPDATE') as authenticated_update_denied;
select not has_table_privilege('authenticated', 'public.orders', 'DELETE') as authenticated_delete_denied;
select exists (select 1 from pg_constraint c join pg_class t on t.oid=c.conrelid where t.relname='orders' and c.conname='orders_currency_code_check') as aed_only;
select exists (select 1 from pg_constraint c join pg_class t on t.oid=c.conrelid where t.relname='orders' and c.conname='orders_original_amount_check') as nonnegative_amount;
rollback;
