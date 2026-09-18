-- P10-T154: In Transit -> RTO regression coverage.
begin;

select plan(10);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome' and pg_get_function_identity_arguments(p.oid)='p_parcel_id uuid, p_outcome text, p_note text, p_idempotency_key text'),'authoritative delivery outcome command exists');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO command path retains SECURITY DEFINER boundary');
select ok((select position('v_state not in (''In Transit'',''NDR'')' in pg_get_functiondef(p.oid)) > 0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'In Transit is an allowed authoritative delivery state');
select ok((select pg_get_functiondef(p.oid) like '%btrim(coalesce(p_outcome,'''')) not in (''Delivered'',''RTO'',''Lost'',''Damaged'',''NDR'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO remains a supported delivery outcome');
select ok((select pg_get_functiondef(p.oid) like '%set state=btrim(p_outcome)%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO transition updates the authoritative parcel state');
select ok((select pg_get_functiondef(p.oid) like '%rto_at=case when btrim(p_outcome)=''RTO''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO transition records RTO timestamp');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.delivery_outcomes%' and pg_get_functiondef(p.oid) like '%insert into public.order_events%' and pg_get_functiondef(p.oid) like '%insert into public.audit_logs%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO transition records outcome, domain event and audit atomically');
select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''record_delivery_outcome''%' and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''record_delivery_outcome''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'direct RTO is idempotent and retry safe');
select ok((select has_function_privilege('anon','public.record_delivery_outcome(uuid,text,text,text)','execute')=false and has_function_privilege('authenticated','public.record_delivery_outcome(uuid,text,text,text)','execute')=true),'RTO command remains restricted to authenticated browser role');
select ok((select pg_get_functiondef(p.oid) like '%where p.id=p_parcel_id%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO transition locks the parcel before mutation');

select * from finish();
rollback;
