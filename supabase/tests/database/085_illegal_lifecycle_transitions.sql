begin;

select plan(8);

select ok((select pg_get_functiondef(p.oid) like '%v_state not in (''In Transit'',''NDR'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'terminal parcel states cannot receive a normal delivery outcome');
select ok((select pg_get_functiondef(p.oid) like '%v_state=''NDR'' and btrim(p_outcome) not in (''Delivered'',''RTO'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'NDR cannot transition to an unsupported outcome');
select ok((select pg_get_functiondef(p.oid) like '%Only In Transit or NDR parcels can receive a delivery outcome%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_delivery_outcome'),'delivery outcomes are rejected for Prepared and other illegal states');
select ok((select pg_get_functiondef(p.oid) like '%v_state not in (''Draft'',''Confirmed'')%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_order'),'cancel_order cannot cancel Active/Completed/Cancelled orders');
select ok((select pg_get_functiondef(p.oid) like '%v_state<>''Prepared''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'cancel_parcel cannot cancel dispatched or terminal parcels');
select ok((select pg_get_functiondef(p.oid) like '%Only Prepared parcels can be cancelled%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='cancel_parcel'),'parcel cancellation has an explicit lifecycle rejection');
select ok((select pg_get_functiondef(p.oid) like '%Only Draft orders can be confirmed%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='confirm_order'),'confirmed/cancelled orders cannot be reconfirmed');
select ok((select pg_get_functiondef(p.oid) like '%Only Prepared parcels can be dispatched%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='dispatch_parcel'),'dispatch cannot reopen a parcel after its Prepared state');

select * from finish();
rollback;
