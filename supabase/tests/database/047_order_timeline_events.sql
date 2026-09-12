begin;

-- P5-T100: Order timeline event contract.
select plan(11);

select ok(
  (select count(*) = 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='order_events' and c.relkind='r'),
  'order_events table exists'
);
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='order_events' and column_name='event_type'), 'timeline stores event type');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='order_events' and column_name='event_time'), 'timeline stores event time');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='order_events' and column_name='performed_by'), 'timeline stores actor');
select ok((select count(*) = 1 from information_schema.columns where table_schema='public' and table_name='order_events' and column_name='metadata'), 'timeline stores event metadata');
select ok((select pg_get_functiondef(p.oid) like '%OrderCreated%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_order'), 'order creation emits OrderCreated');
select ok((select pg_get_functiondef(p.oid) like '%OrderUpdated%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='update_order'), 'order editing emits OrderUpdated');
select ok((select pg_get_functiondef(p.oid) like '%OrderConfirmed%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='confirm_order'), 'confirmation emits OrderConfirmed');
select ok((select pg_get_functiondef(p.oid) like '%OrderCancelled%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_order'), 'cancellation emits OrderCancelled');
select ok((select count(*) = 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='order_events' and t.tgname='trg_order_events_immutable'), 'timeline events are protected by an immutability trigger');
select ok((select pg_get_functiondef(p.oid) like '%order_events%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='prevent_order_event_change'), 'timeline event protection is implemented in database');

select * from finish();
rollback;
