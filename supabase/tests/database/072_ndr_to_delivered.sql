-- P10-T151: NDR -> Delivered regression coverage.
begin;

select plan(12);

select ok(
  to_regprocedure('public.record_delivery_outcome(uuid,text,text,text)') is not null,
  'delivery outcome command exists for NDR completion'
);

select ok(
  (select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public']
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_delivery_outcome'),
  'delivery outcome command remains security definer with pinned search_path'
);

select ok(
  (select has_function_privilege('anon','public.record_delivery_outcome(uuid,text,text,text)','execute')=false
          and has_function_privilege('authenticated','public.record_delivery_outcome(uuid,text,text,text)','execute')=true),
  'delivery outcome command remains browser-role restricted'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%v_state=''NDR''%'
          and pg_get_functiondef(p.oid) like '%btrim(p_outcome)<>''Delivered''%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_delivery_outcome'),
  'NDR parcels are explicitly limited to Delivered as their next outcome'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%v_state not in (''In Transit'',''NDR'')%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_delivery_outcome'),
  'only In Transit and NDR parcels can enter the outcome command'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%where p.id=p_parcel_id%for update%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_delivery_outcome'),
  'parcel row is locked before NDR completion'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%set state=btrim(p_outcome)%'
          and pg_get_functiondef(p.oid) like '%insert into public.delivery_outcomes%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_delivery_outcome'),
  'NDR completion changes state and records the immutable delivery outcome'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%insert into public.order_events%'
          and pg_get_functiondef(p.oid) like '%previous_state%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_delivery_outcome'),
  'NDR completion records the NDR -> Delivered domain transition'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%insert into public.audit_logs%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_delivery_outcome'),
  'NDR completion emits an audit record'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%claim_command_idempotency(''record_delivery_outcome''%'
          and pg_get_functiondef(p.oid) like '%complete_command_idempotency(''record_delivery_outcome''%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_delivery_outcome'),
  'NDR completion remains idempotent and retry safe'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%state'',btrim(p_outcome)%'
          and pg_get_functiondef(p.oid) like '%previous_state%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_delivery_outcome'),
  'command result retains previous and resulting lifecycle states'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%Only In Transit or NDR parcels can receive a delivery outcome%'
          and pg_get_functiondef(p.oid) like '%NDR parcels may only transition to Delivered%'
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='record_delivery_outcome'),
  'NDR transition boundary has explicit rejection messages'
);

select * from finish();
rollback;
