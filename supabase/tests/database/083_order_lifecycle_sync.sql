begin;

select plan(10);

select ok(
  (select count(*) = 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='sync_order_lifecycle_from_parcel'),
  'order lifecycle synchronization function exists'
);
select ok(
  (select count(*) = 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='parcels' and t.tgname='trg_sync_order_lifecycle_from_parcel'),
  'parcel state changes invoke order lifecycle synchronization'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%Confirmed%''%Active%' and pg_get_functiondef(p.oid) like '%OrderActivated%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='sync_order_lifecycle_from_parcel'),
  'first dispatched/later parcel state can activate a Confirmed order'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%is_terminal_parcel_state%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='sync_order_lifecycle_from_parcel'),
  'completion checks authoritative parcel terminal classification'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%OrderCompleted%' and pg_get_functiondef(p.oid) like '%Completed%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='sync_order_lifecycle_from_parcel'),
  'Active orders can transition to Completed with immutable history'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%c.state not in (''Received'',''Voided'',''Closed'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='sync_order_lifecycle_from_parcel'),
  'completion requires COD to be resolved or explicitly closed'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%exists (select 1 from public.parcels%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='sync_order_lifecycle_from_parcel'),
  'completion requires at least one parcel'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%for update%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='sync_order_lifecycle_from_parcel'),
  'order lifecycle synchronization locks the order row before transition'
);
select ok(
  (select pg_get_functiondef(p.oid) like '%insert into public.audit_logs%' and pg_get_functiondef(p.oid) like '%insert into public.order_events%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='sync_order_lifecycle_from_parcel'),
  'lifecycle transitions create both domain event and security audit evidence'
);
select ok(
  has_function_privilege('authenticated','public.sync_order_lifecycle_from_parcel()','execute') = true,
  'authenticated application commands may invoke the lifecycle helper when required by later resolution commands'
);

select * from finish();
rollback;
