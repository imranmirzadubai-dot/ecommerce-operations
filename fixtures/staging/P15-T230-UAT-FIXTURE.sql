-- P15-T230 — Synthetic staging UAT fixture
-- This file is executed ONLY by the Deploy Staging workflow.
-- It intentionally creates clearly marked synthetic data and is not invoked by Deploy Production.
-- Re-running the staging workflow replaces only this fixture's own rows.

begin;

do $$
declare
  v_user uuid;
  c1 uuid;
  c2 uuid;
  c3 uuid;
  c4 uuid;
  c5 uuid;
  c6 uuid;
  o1 uuid;
  o2 uuid;
  o3 uuid;
  o4 uuid;
  o5 uuid;
  o6 uuid;
  o7 uuid;
  o8 uuid;
begin
  select id into v_user
  from public.profiles
  where active = true
  order by created_at
  limit 1;

  if v_user is null then
    raise exception 'P15-T230: no active staging profile exists';
  end if;

  -- Remove only previous P15-T230 synthetic rows.
  delete from public.cod_receipts
   where cod_obligation_id in (
     select id from public.cod_obligations
      where order_id in (select id from public.orders where notes like 'P15-T230-%')
   );

  delete from public.cod_obligation_allocations
   where cod_obligation_id in (
     select id from public.cod_obligations
      where order_id in (select id from public.orders where notes like 'P15-T230-%')
   );

  delete from public.financial_adjustments
   where order_id in (select id from public.orders where notes like 'P15-T230-%');

  delete from public.invoice_records
   where order_id in (select id from public.orders where notes like 'P15-T230-%');

  delete from public.order_events
   where order_id in (select id from public.orders where notes like 'P15-T230-%');

  delete from public.delivery_outcomes
   where parcel_id in (
     select id from public.parcels
      where order_id in (select id from public.orders where notes like 'P15-T230-%')
   );

  delete from public.parcel_items
   where parcel_id in (
     select id from public.parcels
      where order_id in (select id from public.orders where notes like 'P15-T230-%')
   );

  delete from public.cod_obligations
   where order_id in (select id from public.orders where notes like 'P15-T230-%');

  delete from public.parcels
   where order_id in (select id from public.orders where notes like 'P15-T230-%');

  delete from public.order_items
   where order_id in (select id from public.orders where notes like 'P15-T230-%');

  delete from public.orders
   where notes like 'P15-T230-%';

  delete from public.customers
   where normalized_phone in (
     public.normalize_uae_phone('0502300001'),
     public.normalize_uae_phone('0502300002'),
     public.normalize_uae_phone('0502300003'),
     public.normalize_uae_phone('0502300004'),
     public.normalize_uae_phone('0502300005'),
     public.normalize_uae_phone('0502300006')
   );

  insert into public.shippers (name, active)
  values ('UAT P15-T230 Express', true),
         ('UAT P15-T230 Fast Courier', true)
  on conflict (name) do update set active = true;

  insert into public.customers
    (name, phone, normalized_phone, address, city)
  values
    ('UAT Customer 01', '0502300001', public.normalize_uae_phone('0502300001'), 'UAT Address 01', 'Dubai'),
    ('UAT Customer 02', '0502300002', public.normalize_uae_phone('0502300002'), 'UAT Address 02', 'Sharjah'),
    ('UAT Customer 03', '0502300003', public.normalize_uae_phone('0502300003'), 'UAT Address 03', 'Ajman'),
    ('UAT Customer 04', '0502300004', public.normalize_uae_phone('0502300004'), 'UAT Address 04', 'Dubai'),
    ('UAT Customer 05', '0502300005', public.normalize_uae_phone('0502300005'), 'UAT Address 05', 'Abu Dhabi'),
    ('UAT Customer 06', '0502300006', public.normalize_uae_phone('0502300006'), 'UAT Address 06', 'Al Ain');

  select id into c1 from public.customers where normalized_phone = public.normalize_uae_phone('0502300001');
  select id into c2 from public.customers where normalized_phone = public.normalize_uae_phone('0502300002');
  select id into c3 from public.customers where normalized_phone = public.normalize_uae_phone('0502300003');
  select id into c4 from public.customers where normalized_phone = public.normalize_uae_phone('0502300004');
  select id into c5 from public.customers where normalized_phone = public.normalize_uae_phone('0502300005');
  select id into c6 from public.customers where normalized_phone = public.normalize_uae_phone('0502300006');

  insert into public.orders
    (customer_id, order_date, original_amount, lifecycle_state, fulfillment_summary, notes, created_by)
  values (c1, current_date, 125.00, 'Draft', 'Prepared parcel', 'P15-T230-01 Draft UAT order', v_user)
  returning id into o1;

  insert into public.orders
    (customer_id, order_date, original_amount, lifecycle_state, fulfillment_summary, notes, created_by)
  values (c2, current_date, 249.50, 'Confirmed', 'Dispatched parcel', 'P15-T230-02 Confirmed UAT order', v_user)
  returning id into o2;

  insert into public.orders
    (customer_id, order_date, original_amount, lifecycle_state, fulfillment_summary, notes, created_by)
  values (c3, current_date, 399.00, 'Active', 'In-transit parcel', 'P15-T230-03 Active UAT order', v_user)
  returning id into o3;

  insert into public.orders
    (customer_id, order_date, original_amount, lifecycle_state, fulfillment_summary, notes, created_by)
  values (c4, current_date - 1, 549.00, 'Completed', 'Delivered parcel', 'P15-T230-04 Completed UAT order', v_user)
  returning id into o4;

  insert into public.orders
    (customer_id, order_date, original_amount, lifecycle_state, fulfillment_summary, notes, created_by)
  values (c5, current_date, 189.00, 'Active', 'NDR parcel', 'P15-T230-05 NDR UAT order', v_user)
  returning id into o5;

  insert into public.orders
    (customer_id, order_date, original_amount, lifecycle_state, fulfillment_summary, notes, created_by)
  values (c6, current_date, 299.00, 'Cancelled', 'Cancelled parcel', 'P15-T230-06 Cancelled UAT order', v_user)
  returning id into o6;

  insert into public.orders
    (customer_id, order_date, original_amount, lifecycle_state, fulfillment_summary, notes, created_by)
  values (c1, current_date - 2, 799.00, 'Active', 'RTO parcel', 'P15-T230-07 Repeat-customer RTO UAT order', v_user)
  returning id into o7;

  insert into public.orders
    (customer_id, order_date, original_amount, lifecycle_state, fulfillment_summary, notes, created_by)
  values (c2, current_date - 3, 899.00, 'Completed', 'Lost and damaged parcel cases', 'P15-T230-08 Multi-parcel outcome UAT order', v_user)
  returning id into o8;

  insert into public.order_items (order_id, line_no, description, quantity) values
    (o1, 1, 'UAT Wireless Charger', 1),
    (o2, 1, 'UAT Phone Case', 2),
    (o2, 2, 'UAT USB-C Cable', 1),
    (o3, 1, 'UAT Bluetooth Speaker', 1),
    (o4, 1, 'UAT Power Bank', 1),
    (o5, 1, 'UAT Smart Watch', 1),
    (o6, 1, 'UAT Desk Lamp', 1),
    (o7, 1, 'UAT Portable Fan', 2),
    (o8, 1, 'UAT Backpack', 1),
    (o8, 2, 'UAT Travel Adapter', 1);

  insert into public.parcels
    (order_id, parcel_number, barcode, shipper_id, tracking_id, state)
  values
    (o1, 'PCL-UAT-2301', 'PCL-UAT-2301',
      (select id from public.shippers where name='UAT P15-T230 Express'),
      'UAT2301', 'Prepared'),

    (o2, 'PCL-UAT-2302', 'PCL-UAT-2302',
      (select id from public.shippers where name='UAT P15-T230 Fast Courier'),
      'UAT2302', 'Dispatched'),

    (o3, 'PCL-UAT-2303', 'PCL-UAT-2303',
      (select id from public.shippers where name='UAT P15-T230 Express'),
      'UAT2303', 'In Transit'),

    (o4, 'PCL-UAT-2304', 'PCL-UAT-2304',
      (select id from public.shippers where name='UAT P15-T230 Fast Courier'),
      'UAT2304', 'Delivered'),

    (o5, 'PCL-UAT-2305', 'PCL-UAT-2305',
      (select id from public.shippers where name='UAT P15-T230 Express'),
      'UAT2305', 'NDR'),

    (o6, 'PCL-UAT-2306', 'PCL-UAT-2306',
      (select id from public.shippers where name='UAT P15-T230 Fast Courier'),
      'UAT2306', 'Cancelled'),

    (o7, 'PCL-UAT-2307', 'PCL-UAT-2307',
      (select id from public.shippers where name='UAT P15-T230 Express'),
      'UAT2307', 'RTO'),

    (o8, 'PCL-UAT-2308', 'PCL-UAT-2308',
      (select id from public.shippers where name='UAT P15-T230 Fast Courier'),
      'UAT2308A', 'Lost'),

    (o8, 'PCL-UAT-2309', 'PCL-UAT-2309',
      (select id from public.shippers where name='UAT P15-T230 Fast Courier'),
      'UAT2308B', 'Damaged');

  insert into public.parcel_items (parcel_id, order_item_id, quantity)
  select p.id, oi.id, oi.quantity
  from public.parcels p
  join public.order_items oi
    on oi.order_id = p.order_id
  where p.parcel_number in
    ('PCL-UAT-2301','PCL-UAT-2302','PCL-UAT-2303','PCL-UAT-2304',
     'PCL-UAT-2305','PCL-UAT-2306','PCL-UAT-2307')
    and oi.line_no = 1;

  insert into public.parcel_items (parcel_id, order_item_id, quantity)
  select p.id, oi.id, oi.quantity
  from public.parcels p
  join public.order_items oi
    on oi.order_id = p.order_id
  where p.parcel_number = 'PCL-UAT-2302'
    and oi.line_no = 2;

  insert into public.parcel_items (parcel_id, order_item_id, quantity)
  select p.id, oi.id, 1
  from public.parcels p
  join public.order_items oi
    on oi.order_id = p.order_id
  where p.parcel_number = 'PCL-UAT-2308'
    and oi.line_no = 1;

  insert into public.parcel_items (parcel_id, order_item_id, quantity)
  select p.id, oi.id, 1
  from public.parcels p
  join public.order_items oi
    on oi.order_id = p.order_id
  where p.parcel_number = 'PCL-UAT-2309'
    and oi.line_no = 2;

  insert into public.delivery_outcomes (parcel_id, outcome, note, performed_by)
  select id, 'Delivered', 'P15-T230 synthetic UAT delivered case', v_user
  from public.parcels where parcel_number='PCL-UAT-2304';

  insert into public.delivery_outcomes (parcel_id, outcome, note, performed_by)
  select id, 'NDR', 'P15-T230 synthetic UAT NDR case', v_user
  from public.parcels where parcel_number='PCL-UAT-2305';

  insert into public.delivery_outcomes (parcel_id, outcome, note, performed_by)
  select id, 'RTO', 'P15-T230 synthetic UAT RTO case', v_user
  from public.parcels where parcel_number='PCL-UAT-2307';

  insert into public.delivery_outcomes (parcel_id, outcome, note, performed_by)
  select id, 'Lost', 'P15-T230 synthetic UAT lost case', v_user
  from public.parcels where parcel_number='PCL-UAT-2308';

  insert into public.delivery_outcomes (parcel_id, outcome, note, performed_by)
  select id, 'Damaged', 'P15-T230 synthetic UAT damaged case', v_user
  from public.parcels where parcel_number='PCL-UAT-2309';

  insert into public.cod_obligations (order_id, expected_amount, state)
  values
    (o2, 249.50, 'Outstanding'),
    (o3, 399.00, 'Outstanding'),
    (o4, 549.00, 'Closed'),
    (o7, 799.00, 'Exception');

  insert into public.cod_obligation_allocations (cod_obligation_id, parcel_id, expected_amount)
  select co.id, p.id, co.expected_amount
  from public.cod_obligations co
  join public.parcels p on p.order_id = co.order_id;

  insert into public.cod_receipts
    (cod_obligation_id, parcel_id, expected_amount_snapshot, received_amount, state, received_by)
  select co.id, p.id, co.expected_amount, co.expected_amount, 'Received', v_user
  from public.cod_obligations co
  join public.parcels p on p.order_id = co.order_id
  where co.order_id = o4;

  insert into public.cod_receipts
    (cod_obligation_id, parcel_id, expected_amount_snapshot, received_amount, state, received_by)
  select co.id, p.id, co.expected_amount, 500.00, 'Exception', v_user
  from public.cod_obligations co
  join public.parcels p on p.order_id = co.order_id
  where co.order_id = o7;

  insert into public.financial_adjustments
    (order_id, adjustment_type, delta_amount, reason, performed_by)
  values
    (o2, 'UAT_DISCOUNT', -10.00, 'P15-T230 synthetic UAT adjustment', v_user);

  insert into public.invoice_records
    (order_id, invoice_number, template_version, generated_by)
  values
    (o1, 'UAT230-INV-0001', 'v1', v_user),
    (o2, 'UAT230-INV-0002', 'v1', v_user),
    (o3, 'UAT230-INV-0003', 'v1', v_user),
    (o4, 'UAT230-INV-0004', 'v1', v_user),
    (o5, 'UAT230-INV-0005', 'v1', v_user),
    (o7, 'UAT230-INV-0007', 'v1', v_user),
    (o8, 'UAT230-INV-0008', 'v1', v_user);

  insert into public.order_events
    (order_id, parcel_id, event_type, performed_by, notes)
  select p.order_id, p.id,
         case p.state
           when 'Prepared' then 'UAT_PREPARED'
           when 'Dispatched' then 'UAT_DISPATCHED'
           when 'In Transit' then 'UAT_IN_TRANSIT'
           when 'Delivered' then 'UAT_DELIVERED'
           when 'NDR' then 'UAT_NDR'
           when 'Cancelled' then 'UAT_CANCELLED'
           when 'RTO' then 'UAT_RTO'
           when 'Lost' then 'UAT_LOST'
           when 'Damaged' then 'UAT_DAMAGED'
         end,
         v_user,
         'P15-T230 synthetic UAT event'
  from public.parcels p
  where p.parcel_number in
    ('PCL-UAT-2301','PCL-UAT-2302','PCL-UAT-2303','PCL-UAT-2304',
     'PCL-UAT-2305','PCL-UAT-2306','PCL-UAT-2307','PCL-UAT-2308','PCL-UAT-2309');

  -- Embedded verification: fail the staging deployment unless the fixture is complete.
  if (select count(*) from public.customers where normalized_phone like '050230000%') <> 6 then
    raise exception 'P15-T230 verification failed: expected 6 synthetic customers';
  end if;

  if (select count(*) from public.orders where notes like 'P15-T230-%') <> 8 then
    raise exception 'P15-T230 verification failed: expected 8 synthetic orders';
  end if;

  if (select count(*) from public.parcels where parcel_number like 'PCL-UAT-23%') <> 9 then
    raise exception 'P15-T230 verification failed: expected 9 synthetic parcels';
  end if;

  if (select count(*) from public.invoice_records where invoice_number like 'UAT230-%') <> 7 then
    raise exception 'P15-T230 verification failed: expected 7 synthetic invoices';
  end if;

  if (select count(*) from public.cod_obligations where order_id in (o2,o3,o4,o7)) <> 4 then
    raise exception 'P15-T230 verification failed: expected 4 COD obligations';
  end if;
end $$;

commit;
