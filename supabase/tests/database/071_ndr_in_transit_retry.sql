begin;

select plan(12);

select ok(
  to_regprocedure('public.retry_ndr_parcel(uuid,text,text)') is not null,
  'NDR retry command exists'
);

select ok(
  (select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public']
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='retry_ndr_parcel'),
  'NDR retry command is security definer with pinned search_path'
);

select ok(
  (select has_function_privilege('anon','public.retry_ndr_parcel(uuid,text,text)','execute')=false
          and has_function_privilege('authenticated','public.retry_ndr_parcel(uuid,text,text)','execute')=true),
  'NDR retry command is browser-role restricted'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%app_role() not in (''operations'',''admin'')%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='retry_ndr_parcel'),
  'NDR retry requires operations/admin'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%where p.id=p_parcel_id%for update%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='retry_ndr_parcel'),
  'parcel row is locked before NDR retry mutation'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%Only NDR parcels can be retried%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='retry_ndr_parcel'),
  'retry is restricted to NDR state'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%set state=''In Transit''%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='retry_ndr_parcel'),
  'NDR retry returns parcel to In Transit'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%insert into public.order_events%'
          and pg_get_functiondef(p.oid) like '%NDR Retry%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='retry_ndr_parcel'),
  'NDR retry emits a domain event'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%insert into public.audit_logs%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='retry_ndr_parcel'),
  'NDR retry emits an audit record'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''retry_ndr_parcel''%'
          and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''retry_ndr_parcel''%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='retry_ndr_parcel'),
  'NDR retry is idempotent and retry safe'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%Parcel ID is required%'
          and pg_get_functiondef(p.oid) like '%Idempotency key is required%'
          and pg_get_functiondef(p.oid) like '%Parcel not found%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='retry_ndr_parcel'),
  'NDR retry has explicit validation errors'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%previous_state%'
          and pg_get_functiondef(p.oid) like '%retried_at%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='retry_ndr_parcel'),
  'NDR retry records transition context in its result and event metadata'
);

select * from finish();
rollback;
