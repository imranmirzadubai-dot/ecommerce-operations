begin;

select plan(10);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome' and pg_get_function_identity_arguments(p.oid)='p_parcel_id uuid, p_outcome text, p_note text, p_idempotency_key text'),'authoritative delivery outcome command exists');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'direct delivery command retains SECURITY DEFINER boundary');
select ok((select position('v_state<>''In Transit''' in pg_get_functiondef(p.oid)) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'In Transit is the authoritative precondition for direct delivery');
select ok((select pg_get_functiondef(p.oid) like '%btrim(coalesce(p_outcome,'''')) not in (''Delivered'',''RTO'',''Lost'',''Damaged'',''NDR'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'Delivered remains a supported outcome');
select ok((select pg_get_functiondef(p.oid) like '%v_previous_state:=v_state%' and pg_get_functiondef(p.oid) like '%v_previous_state%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'direct delivery preserves transition context');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.delivery_outcomes%' and pg_get_functiondef(p.oid) like '%insert into public.order_events%' and pg_get_functiondef(p.oid) like '%insert into public.audit_logs%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'direct delivery records outcome, event and audit atomically');
select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''record_delivery_outcome''%' and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''record_delivery_outcome''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'direct delivery is idempotent and retry safe');
select ok((select has_function_privilege('anon','public.record_delivery_outcome(uuid,text,text,text)','execute')=false and has_function_privilege('authenticated','public.record_delivery_outcome(uuid,text,text,text)','execute')=true),'direct delivery remains restricted to authenticated browser role');
select ok((select pg_get_functiondef(p.oid) like '%auth.uid() is null or public.app_role() not in (''operations'',''admin'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'direct delivery requires Operations/Admin authorization');
select ok((select pg_get_functiondef(p.oid) like '%where p.id=p_parcel_id%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'direct delivery locks the parcel before mutation');

select * from finish();
rollback;
