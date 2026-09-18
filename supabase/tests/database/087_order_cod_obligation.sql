-- P11-T167: order-level COD obligation contract.
begin;

select plan(10);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_cod_obligation' and pg_get_function_identity_arguments(p.oid)='p_order_id uuid, p_idempotency_key text'),'order-level COD obligation command exists');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_cod_obligation'),'COD obligation command retains SECURITY DEFINER boundary');
select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_cod_obligation'),'COD obligation command requires an authenticated operational role');
select ok((select position('claim_command_idempotency' in pg_get_functiondef(p.oid)) > 0 and position('complete_command_idempotency' in pg_get_functiondef(p.oid)) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_cod_obligation'),'COD obligation creation is idempotent and retry safe');
select ok((select pg_get_functiondef(p.oid) like '%select o.lifecycle_state, o.original_amount%' and pg_get_functiondef(p.oid) like '%where o.id = p_order_id%' and pg_get_functiondef(p.oid) like '%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_cod_obligation'),'COD obligation locks and derives from the authoritative order');
select ok((select pg_get_functiondef(p.oid) like '%v_order_state not in (''Confirmed'',''Active'',''Completed'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_cod_obligation'),'COD obligation lifecycle precondition is enforced');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.cod_obligations(order_id, expected_amount, state)%' and pg_get_functiondef(p.oid) like '%v_original_amount, ''Outstanding''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_cod_obligation'),'COD obligation is created with the order original amount and Outstanding state');
select ok((select pg_get_functiondef(p.oid) like '%CodObligationCreated%' and pg_get_functiondef(p.oid) like '%insert into public.audit_logs%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_cod_obligation'),'COD obligation creation records domain and audit evidence');
select ok((select has_function_privilege('anon','public.create_cod_obligation(uuid,text)','execute')=false and has_function_privilege('authenticated','public.create_cod_obligation(uuid,text)','execute')=true),'COD obligation command remains restricted to authenticated browser role');
select ok((select position('order_id' in pg_get_constraintdef(c.oid)) > 0 from pg_constraint c join pg_class cl on cl.oid=c.conrelid join pg_namespace cn on cn.oid=cl.relnamespace where cn.nspname='public' and cl.relname='cod_obligations' and c.contype='u' and pg_get_constraintdef(c.oid) like '%order_id%'),'COD obligation remains one-per-order through the authoritative unique constraint');

select * from finish();
rollback;
