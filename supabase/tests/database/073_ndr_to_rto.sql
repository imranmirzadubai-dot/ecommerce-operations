-- P10-T152: NDR -> RTO regression coverage.
begin;

select plan(12);

select ok(to_regprocedure('public.record_delivery_outcome(uuid,text,text,text)') is not null,'delivery outcome command exists');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'command remains security definer with pinned search_path');
select ok((select has_function_privilege('anon','public.record_delivery_outcome(uuid,text,text,text)','execute')=false and has_function_privilege('authenticated','public.record_delivery_outcome(uuid,text,text,text)','execute')=true),'browser-role execution remains restricted');
select ok((select pg_get_functiondef(p.oid) like '%v_state=''NDR''%' and pg_get_functiondef(p.oid) like '%not in (''Delivered'',''RTO'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'NDR parcels are limited to Delivered or RTO');
select ok((select pg_get_functiondef(p.oid) like '%v_state not in (''In Transit'',''NDR'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'only In Transit and NDR parcels enter the outcome command');
select ok((select pg_get_functiondef(p.oid) like '%where p.id=p_parcel_id%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'parcel row is locked before transition');
select ok((select pg_get_functiondef(p.oid) like '%set state=btrim(p_outcome)%' and pg_get_functiondef(p.oid) like '%rto_at=case when btrim(p_outcome)=''RTO''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO transition updates state and RTO timestamp');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.delivery_outcomes%' and pg_get_functiondef(p.oid) like '%insert into public.order_events%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO transition records outcome and domain event');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.audit_logs%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO transition emits audit record');
select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''record_delivery_outcome''%' and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''record_delivery_outcome''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO transition remains idempotent');
select ok((select pg_get_functiondef(p.oid) like '%NDR parcels may only transition to Delivered or RTO%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'invalid NDR outcomes have an explicit rejection boundary');
select ok((select pg_get_functiondef(p.oid) like '%Only In Transit or NDR parcels can receive a delivery outcome%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'non-lifecycle states remain rejected');

select * from finish();
rollback;
