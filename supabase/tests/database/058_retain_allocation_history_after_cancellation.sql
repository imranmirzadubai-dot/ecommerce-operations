begin;

select plan(8);

select ok((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancel_parcel command exists');
select ok((select pg_get_functiondef(p.oid) like '%update public.parcel_items%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancellation updates allocation rows in place');
select ok((select pg_get_functiondef(p.oid) like '%set allocation_state=''Reversed''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancelled allocations are retained as Reversed history');
select ok((select pg_get_functiondef(p.oid) like '%where parcel_id=p_parcel_id%' and pg_get_functiondef(p.oid) like '%allocation_state=''Allocated''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'only active allocations are transitioned');
select ok((select pg_get_functiondef(p.oid) not like '%delete from public.parcel_items%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancellation never deletes parcel allocation rows');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.order_events%' and pg_get_functiondef(p.oid) like '%ParcelCancelled%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancellation records an immutable domain event');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.audit_logs%' and pg_get_functiondef(p.oid) like '%''cancel_parcel''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancellation records audit history');
select ok((select pg_get_functiondef(p.oid) like '%allocation_reversal%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancellation event records allocation reversal outcome');

select * from finish();
rollback;
