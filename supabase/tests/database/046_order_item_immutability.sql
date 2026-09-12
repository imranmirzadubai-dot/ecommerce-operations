begin;

-- P5-T099: order item description/quantity and item-set immutability after confirmation.
select plan(10);

select ok((select count(*) = 1 from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_order_item_change'), 'order item guard function exists');
select ok((select count(*) = 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid where c.oid='public.order_items'::regclass and t.tgname='trg_order_items_immutable_after_confirmation' and not t.tgisinternal), 'order item immutability trigger exists');
select ok((select pg_get_functiondef(p.oid) like '%Order items are immutable after confirmation%' from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_order_item_change'), 'guard raises the locked-item error');
select ok((select pg_get_functiondef(p.oid) like '%v_old_state <> ''Draft''%' from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_order_item_change'), 'guard rejects changes originating from non-Draft orders');
select ok((select pg_get_functiondef(p.oid) like '%v_new_state <> ''Draft''%' from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_order_item_change'), 'guard rejects changes targeting non-Draft orders');
select ok((select pg_get_functiondef(p.oid) like '%tg_op <> ''INSERT''%' and pg_get_functiondef(p.oid) like '%tg_op <> ''DELETE''%' from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_order_item_change'), 'guard distinguishes insert, update and delete row contexts');
select ok((select pg_get_triggerdef(t.oid) like '%BEFORE INSERT OR UPDATE OR DELETE ON public.order_items%' from pg_trigger t where t.tgname='trg_order_items_immutable_after_confirmation' and t.tgrelid='public.order_items'::regclass), 'guard covers insert, update and delete');
select ok((select pg_get_functiondef(p.oid) like '%return case when tg_op = ''DELETE'' then old else new end%' from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_order_item_change'), 'guard preserves trigger row semantics');
select ok((select has_function_privilege('public','public.prevent_confirmed_order_item_change()','execute') = false), 'guard function is not executable by public callers');
select ok((select pg_get_functiondef(p.oid) like '%select lifecycle_state into v_old_state from public.orders%' and pg_get_functiondef(p.oid) like '%select lifecycle_state into v_new_state from public.orders%' from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_order_item_change'), 'guard derives lock state from both owning orders');

select * from finish();
rollback;
