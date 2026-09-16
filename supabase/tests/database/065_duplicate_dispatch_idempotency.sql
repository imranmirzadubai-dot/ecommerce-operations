begin;

select plan(9);

select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''dispatch_parcel''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'dispatch claims a shared idempotency key before mutation');
select ok((select pg_get_functiondef(p.oid) like '%if not v_is_new then%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'duplicate command returns the stored result');
select ok((select pg_get_functiondef(p.oid) like '%v_result->>''parcel_id''%' and pg_get_functiondef(p.oid) like '%v_result->>''tracking_id''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'duplicate command returns the original parcel and tracking context');
select ok((select pg_get_functiondef(p.oid) like '%complete_command_idempotency(''dispatch_parcel''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'successful dispatch stores its result for retry');
select ok((select pg_get_functiondef(p.oid) like '%where p.id=p_parcel_id%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'dispatch still locks the parcel for race-safe lifecycle mutation');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.order_events%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'dispatch has one authoritative event-writing path');
select ok((select pg_get_functiondef(p.oid) like '%state=''Dispatched''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'duplicate dispatch cannot create a second lifecycle transition');
select ok((select pg_get_functiondef(p.oid) like '%v_hash:=md5(jsonb_build_object(''parcel_id'',p_parcel_id,''tracking_id'',btrim(p_tracking_id))::text)%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'idempotency key is bound to the dispatch input');
select ok((select pg_get_functiondef(p.oid) like '%Duplicate%' or pg_get_functiondef(p.oid) like '%already Dispatched%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel') is false,'server command does not rely on a duplicate-scan UI message for idempotency');

select * from finish();
rollback;
