-- P15-T239: rollback-scoped runtime rehearsal of the historical migration pipeline.
-- Synthetic source rows only. The production-import command is executed inside the same
-- transaction and rolled back at the end; no staging business data is retained.

begin;
select plan(10);
set local role postgres;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000239';

insert into auth.users (id, aud, role, email, encrypted_password)
values ('00000000-0000-0000-0000-000000000239'::uuid, 'authenticated', 'authenticated', 'p15-t239@example.test', 'test-only');

insert into public.profiles(id,name,email,role,active)
values ('00000000-0000-0000-0000-000000000239'::uuid, 'P15-T239 Rehearsal Admin', 'p15-t239@example.test', 'admin', true);

do $$
declare
  v_batch uuid;
  v_row_count int;
  v_valid int;
  v_errors int;
  v_normalized int;
  v_identities int;
  v_matched int;
  v_create int;
  v_match_errors int;
  v_preview_create int;
  v_preview_update int;
  v_preview_errors int;
  v_stage_reconciled boolean;
  v_money_reconciled boolean;
  v_orders int;
  v_items int;
  v_customers_created int;
  v_customers_reused int;
begin
  select batch_id,row_count into v_batch,v_row_count
  from public.stage_import_file(
    'P15-T239-REHEARSAL',
    'P15-T239-rehearsal.csv',
    '[
      {"source_record_id":"T239-001","name":"UAT Customer 01","phone":"0502300001","address":"UAT Address 01","city":"Dubai","order_date":"2026-09-25","amount":"100.00","description":"Historical Rehearsal Item 1","quantity":"1"},
      {"source_record_id":"T239-002","name":"T239 New Customer","phone":"0502399999","address":"T239 Rehearsal Address","city":"Ajman","order_date":"2026-09-26","amount":"200.00","description":"Historical Rehearsal Item 2","quantity":"2"}
    ]'::jsonb,
    't239-stage-rehearsal'
  );
  perform is(v_row_count,2,'stage_import_file retains two source rows');

  select batch_id,row_count into v_batch,v_row_count
  from public.map_import_columns(
    v_batch,
    '{"name":"customer_name","phone":"phone","address":"address","city":"city","order_date":"order_date","amount":"amount","description":"item_description","quantity":"quantity"}'::jsonb,
    't239-map-rehearsal'
  );

  select valid_count,error_count into v_valid,v_errors
  from public.validate_import_rows(
    v_batch,
    '["customer_name","phone","order_date","amount","item_description","quantity"]'::jsonb,
    '{"customer_name":"text","phone":"text","address":"text","city":"text","order_date":"date","amount":"number","item_description":"text","quantity":"integer"}'::jsonb,
    '["order_date"]'::jsonb,
    '["amount"]'::jsonb,
    't239-validate-rehearsal'
  );
  perform is(v_valid,2,'all staged rows validate');
  perform is(v_errors,0,'validation records no errors');

  select normalized_count,error_count into v_normalized,v_errors
  from public.normalize_import_phone_fields(v_batch,'["phone"]'::jsonb,'+971','t239-normalize-rehearsal');
  perform is(v_normalized,2,'all phones normalize');

  select identity_count into v_identities
  from public.assign_import_source_identity(v_batch,'["customer_name","phone","order_date","amount","item_description","quantity"]'::jsonb,'t239-identity-rehearsal');
  perform is(v_identities,2,'all rows receive deterministic source identity');

  select matched_count,create_count,error_count into v_matched,v_create,v_match_errors
  from public.match_import_customers(v_batch,'phone','t239-match-rehearsal');
  perform is(v_matched,1,'one existing customer is matched');
  perform is(v_create,1,'one new customer is classified for creation');
  perform is(v_match_errors,0,'customer matching records no exceptions');

  select create_count,update_count,error_count into v_preview_create,v_preview_update,v_preview_errors
  from public.preview_import_customer_changes(v_batch,'t239-preview-rehearsal');
  if v_preview_create <> 1 or v_preview_update <> 1 or v_preview_errors <> 0 then
    raise exception 'preview counts mismatch';
  end if;

  select reconciled into v_stage_reconciled
  from public.reconcile_import_staging(v_batch,'t239-stage-recon-rehearsal');
  if not v_stage_reconciled then raise exception 'staging reconciliation failed'; end if;

  select reconciled into v_money_reconciled
  from public.reconcile_import_monetary_counts(v_batch,'amount',2,300.00,'t239-money-recon-rehearsal');
  if not v_money_reconciled then raise exception 'monetary reconciliation failed'; end if;

  select order_create_count,order_item_create_count,customer_create_count,customer_reuse_count
    into v_orders,v_items,v_customers_created,v_customers_reused
  from public.import_historical_batch(
    v_batch,
    '{"customer_name_field":"customer_name","phone_field":"phone","address_field":"address","city_field":"city","order_date_field":"order_date","amount_field":"amount","item_description_field":"item_description","quantity_field":"quantity"}'::jsonb,
    't239-import-rehearsal'
  );

  if v_orders <> 2 or v_items <> 2 or v_customers_created <> 1 or v_customers_reused <> 1 then
    raise exception 'historical import result mismatch';
  end if;
end $$;

select is((select count(*) from public.orders where historical_import_batch_id is not null),2::bigint,'two historical orders carry durable source lineage');
select is((select count(*) from public.order_items oi join public.orders o on o.id=oi.order_id where o.historical_import_batch_id is not null),2::bigint,'each historical source row creates one order item');
select is((select count(*) from public.import_rows where source_identity is not null and status='Imported'),2::bigint,'both source rows are marked Imported');

select * from finish();
rollback;