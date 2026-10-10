begin;

select plan(8);

select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome' and pg_get_functiondef(p.oid) like '%v_state not in (''In Transit'',''NDR'')%'),'terminal parcel states cannot receive a normal delivery outcome');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome' and pg_get_functiondef(p.oid) like '%v_state=''NDR'' and btrim(p_outcome) not in (''Delivered'',''RTO'')%'),'NDR cannot transition to an unsupported outcome');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome' and pg_get_functiondef(p.oid) like '%Only In Transit or NDR parcels can receive a delivery outcome%'),'delivery outcomes are rejected for Prepared and other illegal states');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_order' and pg_get_functiondef(p.oid) like '%v_state not in (''Draft'',''Confirmed'')%'),'cancel_order cannot cancel Active/Completed/Cancelled orders');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel' and pg_get_functiondef(p.oid) like '%v_state<>''Prepared''%'),'cancel_parcel cannot cancel dispatched or terminal parcels');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel' and pg_get_functiondef(p.oid) like '%Only Prepared parcels can be cancelled%'),'parcel cancellation has an explicit lifecycle rejection');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='confirm_order' and pg_get_functiondef(p.oid) like '%Only Draft orders can be confirmed%'),'confirmed/cancelled orders cannot be reconfirmed');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel' and pg_get_functiondef(p.oid) like '%Only Prepared parcels can be dispatched%'),'dispatch cannot reopen a parcel after its Prepared state');

select * from finish();
rollback;
