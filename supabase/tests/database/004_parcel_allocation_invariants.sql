-- T039 pgTAP harness fix: keep behavioral assertions at top level.
begin;
set constraints all immediate;
select plan(12);

select has_function('public','assert_order_item_allocation_invariant',ARRAY['uuid'],'allocation invariant helper exists');
select has_function('public','validate_parcel_item_allocation',ARRAY[]::text[],'allocation trigger function exists');
select has_function('public','assert_order_item_physical_outcome_invariant',ARRAY['uuid'],'physical outcome invariant helper exists');
select has_function('public','validate_parcel_state_allocation',ARRAY[]::text[],'parcel state allocation trigger function exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_parcel_item_allocation'),'parcel item allocation trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_parcel_state_allocation'),'parcel state allocation trigger exists');

do $$
declare
  v_actor uuid := '00000000-0000-0000-0000-000000000039';
  v_customer uuid;
  v_order uuid;
  v_item uuid;
  v_parcel_a uuid;
  v_parcel_b uuid;
  v_parcel_a_number text;
  v_parcel_b_number text;
  v_ok boolean := false;
  v_terminal_ok boolean := false;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
  values(v_actor,'authenticated','authenticated','t039@example.invalid','x',now(),now(),'{}','{}');
  insert into public.profiles(id,name,email,role,active)
  values(v_actor,'T039 Test','t039@example.invalid','admin',true);
  insert into public.customers(name,phone,normalized_phone)
  values('T039 Test Customer','0500000039','+971500000039')
  returning id into v_customer;
  insert into public.orders(customer_id,original_amount,created_by)
  values(v_customer,100,v_actor)
  returning id into v_order;
  insert into public.order_items(order_id,line_no,description,quantity)
  values(v_order,1,'T039 allocation test item',3)
  returning id into v_item;

  v_parcel_a_number := 'PCL-' || lpad(nextval('public.parcel_number_seq')::text,6,'0');
  insert into public.parcels(order_id,parcel_number,barcode)
  values(v_order,v_parcel_a_number,v_parcel_a_number)
  returning id into v_parcel_a;

  v_parcel_b_number := 'PCL-' || lpad(nextval('public.parcel_number_seq')::text,6,'0');
  insert into public.parcels(order_id,parcel_number,barcode)
  values(v_order,v_parcel_b_number,v_parcel_b_number)
  returning id into v_parcel_b;

  insert into public.parcel_items(parcel_id,order_item_id,quantity)
  values(v_parcel_a,v_item,2);

  begin
    insert into public.parcel_items(parcel_id,order_item_id,quantity)
    values(v_parcel_b,v_item,2);
  exception when others then
    v_ok := true;
  end;

  update public.parcel_items
     set allocation_state='Reversed'
   where parcel_id=v_parcel_a and order_item_id=v_item and allocation_state='Allocated';

  insert into public.parcel_items(parcel_id,order_item_id,quantity)
  values(v_parcel_b,v_item,3);

  begin
    update public.parcels set state='Delivered' where id=v_parcel_a;
    v_terminal_ok := true;
  exception when others then
    v_terminal_ok := false;
  end;

  create temporary table _t039_results (
    item_id uuid not null,
    over_allocation_rejected boolean not null,
    terminal_state_accepted boolean not null
  ) on commit drop;

  insert into _t039_results(item_id,over_allocation_rejected,terminal_state_accepted)
  values(v_item,v_ok,v_terminal_ok);
end;
$$;

select ok((select over_allocation_rejected from _t039_results limit 1),'active allocation above ordered quantity is rejected');
select ok((select coalesce(sum(quantity),0)=3 from public.parcel_items where order_item_id=(select item_id from _t039_results limit 1) and allocation_state='Allocated'),'reversed historical allocation does not consume active quantity');
select ok((select terminal_state_accepted from _t039_results limit 1),'terminal parcel state is accepted when allocated quantity is valid');
select ok((select coalesce(sum(pi.quantity),0)=3 from public.parcel_items pi where pi.order_item_id=(select item_id from _t039_results limit 1) and pi.allocation_state='Allocated'),'terminal physical quantity remains bounded by the order item quantity');

select ok((select relrowsecurity from pg_class where oid='public.parcel_items'::regclass),'parcel_items has RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.parcels'::regclass),'parcels has RLS enabled');
select * from finish();
rollback;
