begin;
select plan(10);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_effective_order_amount' and pg_get_function_identity_arguments(p.oid)='p_order_id uuid'),'effective amount function exists with expected signature');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_effective_order_amount'),'effective amount function uses SECURITY DEFINER and controlled search_path');
select ok((select pg_get_function_result(p.oid)='numeric' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_effective_order_amount'),'effective amount is returned as exact PostgreSQL numeric');
select ok((select position('original_amount' in pg_get_functiondef(p.oid))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_effective_order_amount'),'calculation uses authoritative order original amount');
select ok((select position('sum(fa.delta_amount)' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_effective_order_amount'),'calculation aggregates signed financial adjustment deltas');
select ok((select position('coalesce(sum(fa.delta_amount), 0::numeric(12,2))' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_effective_order_amount'),'no-adjustment case contributes zero');
select ok((select position('round(v_original_amount + v_adjustment_total, 2)' in lower(pg_get_functiondef(p.oid)))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_effective_order_amount'),'final effective amount remains two-decimal exact arithmetic');
select ok((select position('auth.uid() is null' in pg_get_functiondef(p.oid))>0 and position('public.app_role() <> ''admin''' in pg_get_functiondef(p.oid))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_effective_order_amount'),'calculation is restricted to authenticated Admin callers');
select ok((select position('Order ID is required' in pg_get_functiondef(p.oid))>0 and position('Order not found' in pg_get_functiondef(p.oid))>0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_effective_order_amount'),'invalid and unknown order IDs fail explicitly');
select ok((select has_function_privilege('public','public.get_effective_order_amount(uuid)','execute')=false and has_function_privilege('anon','public.get_effective_order_amount(uuid)','execute')=false and has_function_privilege('authenticated','public.get_effective_order_amount(uuid)','execute')=true),'function access is restricted to authenticated callers');

select * from finish();
rollback;
