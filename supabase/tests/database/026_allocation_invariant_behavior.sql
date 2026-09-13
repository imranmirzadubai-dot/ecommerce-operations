-- P3-T075: parcel allocation invariant behavior tests.
-- Designed for staging with pgTAP installed.

begin;
set constraints all immediate;
select plan(6);

select ok((select count(*) = 1 from pg_trigger where tgname='trg_enforce_parcel_item_allocation_quantity' and tgrelid='public.parcel_items'::regclass), 'allocation quantity constraint trigger exists');
select ok((select p.prosecdef and p.proconfig @> array['search_path=pg_catalog, public'] from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='enforce_parcel_item_allocation_quantity'), 'allocation trigger function is SECURITY DEFINER with pinned search_path');

do $$
declare
  v_actor uuid := '00000000-0000-0000-0000-000000000075';
  v_customer uuid; v_order uuid; v_item uuid; v_parcel uuid; v_number text;
  v_rejected boolean := false;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
  values(v_actor,'authenticated','authenticated','t075@example.invalid','x',now(),now(),'{}','{}');
  insert into public.profiles(id,name,email,role,active) values(v_actor,'T075 Test','t075@example.invalid','admin',true);
  insert into public.customers(name,phone,normalized_phone) values('T075 Customer','0500000075','+971500000075') returning id into v_customer;
  insert into public.orders(customer_id,original_amount,created_by) values(v_customer,100,v_actor) returning id into v_order;
  insert into public.order_items(order_id,line_no,description,quantity) values(v_order,1,'T075 allocation item',3) returning id into v_item;
  v_number := 'PCL-' || lpad(nextval('public.parcel_number_seq')::text,6,'0');
  insert into public.parcels(order_id,parcel_number,barcode) values(v_order,v_number,v_number) returning id into v_parcel;

  insert into public.parcel_items(parcel_id,order_item_id,quantity,allocation_state) values(v_parcel,v_item,2,'Allocated');
  begin
    insert into public.parcel_items(parcel_id,order_item_id,quantity,allocation_state) values(v_parcel,v_item,2,'Allocated');
  exception when check_violation then
    v_rejected := true;
  end;
  perform ok(v_rejected, 'negative: active parcel allocation exceeding ordered quantity is rejected');

  update public.parcel_items set allocation_state='Reversed' where parcel_id=v_parcel and order_item_id=v_item and allocation_state='Allocated';
  insert into public.parcel_items(parcel_id,order_item_id,quantity,allocation_state) values(v_parcel,v_item,3,'Allocated');
  perform ok((select coalesce(sum(quantity),0)=3 from public.parcel_items where order_item_id=v_item and allocation_state='Allocated'), 'positive: reversed allocation no longer consumes active quantity');
  perform ok((select count(*)=1 from public.parcel_items where order_item_id=v_item and allocation_state='Reversed' and quantity=2), 'positive: reversed allocation history is retained');
end;
$$;

select ok((select relrowsecurity from pg_class where oid='public.parcel_items'::regclass), 'parcel_items retains RLS');
select ok((select has_table_privilege('authenticated','public.parcel_items','insert') = false), 'negative: authenticated direct parcel-item INSERT is denied at grant layer');
select * from finish();
rollback;
