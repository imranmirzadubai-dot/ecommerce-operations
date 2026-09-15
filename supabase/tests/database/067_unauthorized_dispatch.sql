begin;

select plan(9);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel' and pg_get_function_identity_arguments(p.oid)='p_parcel_id uuid, p_tracking_id text, p_idempotency_key text'),'dispatch command exists for authorization test');

select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'dispatch command executes through controlled SECURITY DEFINER boundary');

select ok((select pg_get_functiondef(p.oid) like '%auth.uid() is null or public.app_role() not in (''operations'',''admin'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'unauthenticated and non-Operations/Admin callers are rejected');

select ok((select pg_get_functiondef(p.oid) like '%Operations or admin role required%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'unauthorized dispatch returns explicit permission error');

select ok((select has_function_privilege('anon','public.dispatch_parcel(uuid,text,text)','execute')=false and has_function_privilege('authenticated','public.dispatch_parcel(uuid,text,text)','execute')=true),'only authenticated callers can reach the command boundary');

select ok((select has_table_privilege('authenticated','public.parcels','INSERT')=false and has_table_privilege('authenticated','public.parcels','UPDATE')=false and has_table_privilege('authenticated','public.parcels','DELETE')=false),'authenticated browser role cannot directly mutate parcels');

select ok((select has_table_privilege('anon','public.parcels','INSERT')=false and has_table_privilege('anon','public.parcels','UPDATE')=false and has_table_privilege('anon','public.parcels','DELETE')=false),'anonymous role cannot directly mutate parcels');

select ok((select pg_get_functiondef(p.oid) like '%if auth.uid() is null%' and pg_get_functiondef(p.oid) like '%public.app_role()%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'authorization is evaluated inside the database command');

select ok((select pg_get_functiondef(p.oid) like '%revoke execute on function public.dispatch_parcel%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'dispatch execution is explicitly restricted by grants');

select * from finish();
rollback;
