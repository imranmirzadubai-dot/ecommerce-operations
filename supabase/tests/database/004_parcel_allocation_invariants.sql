begin;
set constraints all immediate;
select plan(14);

select has_function('public','assert_order_item_allocation_invariant',ARRAY['uuid'],'allocation invariant helper exists');
select has_function('public','validate_parcel_item_allocation',ARRAY[]::text[],'allocation trigger function exists');
select has_function('public','assert_order_item_physical_outcome_invariant',ARRAY['uuid'],'physical outcome invariant helper exists');
select has_function('public','validate_parcel_state_allocation',ARRAY[]::text[],'parcel state allocation trigger function exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_parcel_item_allocation'),'parcel item allocation trigger exists');
select ok(exists(select 1 from pg_trigger where tgname='trg_validate_parcel_state_allocation'),'parcel state allocation trigger exists');
select ok((select format_type(a.atttypid,a.atttypmod)='integer' from pg_attribute a where a.attrelid='public.order_items'::regclass and a.attname='quantity' and not a.attisdropped),'order item quantity is INTEGER');
select ok((select format_type(a.atttypid,a.atttypmod)='integer' from pg_attribute a where a.attrelid='public.parcel_items'::regclass and a.attname='quantity' and not a.attisdropped),'parcel allocation quantity is INTEGER');
select ok((select exists(select 1 from pg_constraint c where c.conrelid='public.order_items'::regclass and pg_get_constraintdef(c.oid) like '%quantity > 0%')),'order item quantity has positive-value check');
select ok((select exists(select 1 from pg_constraint c where c.conrelid='public.parcel_items'::regclass and pg_get_constraintdef(c.oid) like '%quantity > 0%')),'parcel allocation quantity has positive-value check');

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
  perform ok(v_ok,'active allocation above ordered quantity is rejected');

  update public.parcel_items
     set allocation_state='Reversed'
   where parcel_id=v_parcel_a and order_item_id=v_item and allocation_state='Allocated';

  insert into public.parcel_items(parcel_id,order_item_id,quantity)
  values(v_parcel_b,v_item,3);
  perform ok((select coalesce(sum(quantity),0)=3 from public.parcel_items where order_item_id=v_item and allocation_state='Allocated'),'reversed historical allocation does not consume active quantity');

  begin
    update public.parcels set state='Delivered' where id=v_parcel_a;
    perform ok(true,'terminal parcel state is accepted when allocated quantity is valid');
  exception when others then
    perform ok(false,'terminal parcel state is accepted when allocated quantity is valid');
  end;
  perform ok((select coalesce(sum(pi.quantity),0)=3 from public.parcel_items pi where pi.order_item_id=v_item and pi.allocation_state='Allocated'),'terminal physical quantity remains bounded by the order item quantity');
end;
$$;

select ok((select relrowsecurity from pg_class where oid='public.parcel_items'::regclass),'parcel_items has RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.parcels'::regclass),'parcels has RLS enabled');
select * from finish();
rollback;
