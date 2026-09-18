begin;

select plan(7);

select ok((select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''record_delivery_outcome''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO processing uses the shared command idempotency boundary');
select ok((select pg_get_functiondef(p.oid) like '%complete_command_idempotency(''record_delivery_outcome''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'successful RTO processing stores its completed result for retry');
select ok((select pg_get_functiondef(p.oid) like '%if v_state=''NDR'' and btrim(p_outcome) not in (''Delivered'',''RTO'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO is explicitly permitted from NDR');
select ok((select pg_get_functiondef(p.oid) like '%v_state not in (''In Transit'',''NDR'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'a second RTO scan against an RTO parcel is rejected by the terminal-state guard');
select ok((select pg_get_functiondef(p.oid) like '%v_result->>''outcome_id''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'an idempotent retry returns the original RTO result rather than creating a second outcome');
select ok((select pg_get_functiondef(p.oid) like '%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'RTO processing locks the parcel before state validation');
select ok(has_function_privilege('anon','public.record_delivery_outcome(uuid,text,text,text)','execute')=false and has_function_privilege('authenticated','public.record_delivery_outcome(uuid,text,text,text)','execute')=true),'duplicate RTO scans remain inside the authenticated command boundary');

select * from finish();
rollback;
