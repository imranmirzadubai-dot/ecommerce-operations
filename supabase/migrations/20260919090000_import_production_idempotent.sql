-- P12-T194: idempotent production import for validated historical batches.
-- One staged source row represents one historical order/item record. The command creates
-- missing customers, reuses customers matched by T190, and creates the order plus one
-- order-item atomically. No parcel is created here; fulfillment remains a later workflow.

create or replace function public.import_historical_batch(
  p_batch_id uuid,
  p_field_map jsonb,
  p_idempotency_key text
)
returns table(
  batch_id uuid,
  row_count integer,
  customer_create_count integer,
  customer_reuse_count integer,
  order_create_count integer,
  order_item_create_count integer
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_status text;
  v_row_count integer;
  v_customer_create_count integer := 0;
  v_customer_reuse_count integer := 0;
  v_order_create_count integer := 0;
  v_order_item_create_count integer := 0;
  v_claim record;
  v_result jsonb;
  v_summary jsonb;
  v_staging_reconciled boolean;
  v_monetary_reconciled boolean;
  v_name_field text;
  v_phone_field text;
  v_address_field text;
  v_city_field text;
  v_order_date_field text;
  v_amount_field text;
  v_item_description_field text;
  v_quantity_field text;
  v_customer_id uuid;
  v_order_id uuid;
  v_order_date date;
  v_amount numeric(12,2);
  v_quantity integer;
  v_name text;
  v_phone text;
  v_item_description text;
  r record;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null or public.app_role() is null then
    raise exception using errcode='42501', message='Authentication required';
  end if;
  if public.app_role() <> 'admin' then
    raise exception using errcode='42501', message='Admin role required';
  end if;
  if p_batch_id is null then
    raise exception using errcode='22023', message='Import batch is required';
  end if;
  if jsonb_typeof(p_field_map) <> 'object' then
    raise exception using errcode='22023', message='Production import field map must be a JSON object';
  end if;

  v_name_field := btrim(coalesce(p_field_map->>'customer_name_field', ''));
  v_phone_field := btrim(coalesce(p_field_map->>'phone_field', ''));
  v_address_field := btrim(coalesce(p_field_map->>'address_field', ''));
  v_city_field := btrim(coalesce(p_field_map->>'city_field', ''));
  v_order_date_field := btrim(coalesce(p_field_map->>'order_date_field', ''));
  v_amount_field := btrim(coalesce(p_field_map->>'amount_field', ''));
  v_item_description_field := btrim(coalesce(p_field_map->>'item_description_field', ''));
  v_quantity_field := btrim(coalesce(p_field_map->>'quantity_field', ''));

  if v_name_field = '' or v_phone_field = '' or v_order_date_field = ''
     or v_amount_field = '' or v_item_description_field = '' or v_quantity_field = '' then
    raise exception using errcode='22023', message='Production import requires customer name, phone, order date, amount, item description, and quantity fields';
  end if;
  if v_address_field = '' then v_address_field := null; end if;
  if v_city_field = '' then v_city_field := null; end if;

  select b.status, b.reconciliation_summary into v_status, v_summary
  from public.import_batches b
  where b.id = p_batch_id and b.initiated_by = v_actor_id
  for update;
  if not found then
    raise exception using errcode='42501', message='Import batch is not accessible';
  end if;
  if v_status <> 'Ready' then
    raise exception using errcode='55000', message='Import batch must be Ready before production import';
  end if;

  v_staging_reconciled := coalesce((v_summary->'staging_reconciliation'->>'reconciled')::boolean, false);
  v_monetary_reconciled := coalesce((v_summary->'monetary_count_reconciliation'->>'reconciled')::boolean, false);
  if not v_staging_reconciled or not v_monetary_reconciled then
    raise exception using errcode='55000', message='Import batch must pass staging and monetary/count reconciliation before production import';
  end if;

  select * into v_claim from public.claim_command_idempotency(
    'import_historical_batch', p_idempotency_key,
    md5(concat_ws('|', p_batch_id::text, p_field_map::text))
  );
  if not v_claim.is_new then
    return query select (v_claim.result->>'batch_id')::uuid,
      (v_claim.result->>'row_count')::integer,
      (v_claim.result->>'customer_create_count')::integer,
      (v_claim.result->>'customer_reuse_count')::integer,
      (v_claim.result->>'order_create_count')::integer,
      (v_claim.result->>'order_item_create_count')::integer;
    return;
  end if;

  update public.import_batches set status='Importing', started_at=coalesce(started_at, now()) where id=p_batch_id;
  select count(*)::integer into v_row_count from public.import_rows where batch_id=p_batch_id;
  if v_row_count = 0 then
    raise exception using errcode='22023', message='Import batch contains no rows';
  end if;
  if exists (select 1 from public.import_rows r where r.batch_id=p_batch_id and (r.status <> 'Valid' or r.customer_match_status not in ('Matched','Create'))) then
    raise exception using errcode='55000', message='Every import row must be Valid and customer-classified as Matched or Create';
  end if;

  for r in select * from public.import_rows where batch_id=p_batch_id order by source_row_number loop
    v_name := btrim(r.normalized_data ->> v_name_field);
    v_phone := btrim(r.normalized_data ->> v_phone_field);
    v_order_date := (r.normalized_data ->> v_order_date_field)::date;
    v_amount := (r.normalized_data ->> v_amount_field)::numeric(12,2);
    v_item_description := btrim(r.normalized_data ->> v_item_description_field);
    v_quantity := (r.normalized_data ->> v_quantity_field)::integer;
    if v_name='' or v_phone !~ '^\\+[1-9][0-9]{6,14}$' or v_item_description='' or v_quantity <= 0 or v_amount < 0 then
      raise exception using errcode='22023', message='Production import row contains invalid canonical customer/order/item values';
    end if;

    if r.customer_match_status='Matched' then
      v_customer_id := r.matched_customer_id;
      if v_customer_id is null then
        raise exception using errcode='55000', message='Matched import row is missing matched customer';
      end if;
      v_customer_reuse_count := v_customer_reuse_count + 1;
    else
      insert into public.customers(name, phone, normalized_phone, address, city)
      values(v_name, v_phone, v_phone,
        case when v_address_field is null then null else nullif(btrim(r.normalized_data ->> v_address_field),'') end,
        case when v_city_field is null then null else nullif(btrim(r.normalized_data ->> v_city_field),'') end)
      on conflict (normalized_phone) do nothing returning id into v_customer_id;
      if v_customer_id is null then
        select c.id into v_customer_id from public.customers c where c.normalized_phone=v_phone;
        v_customer_reuse_count := v_customer_reuse_count + 1;
      else
        v_customer_create_count := v_customer_create_count + 1;
      end if;
    end if;

    insert into public.orders(customer_id, order_date, currency_code, original_amount, lifecycle_state, notes, created_by)
    values(v_customer_id, v_order_date, 'AED', v_amount, 'Completed', 'Historical import; source row '||r.source_row_number::text, v_actor_id)
    returning id into v_order_id;
    v_order_create_count := v_order_create_count + 1;

    insert into public.order_items(order_id, line_no, description, quantity)
    values(v_order_id,1,v_item_description,v_quantity);
    v_order_item_create_count := v_order_item_create_count + 1;

    insert into public.order_events(order_id,event_type,performed_by,notes,metadata)
    values(v_order_id,'Historical Import',v_actor_id,
      'Imported from historical source row '||r.source_row_number::text,
      jsonb_build_object('batch_id',p_batch_id,'source_row_number',r.source_row_number,'source_record_id',r.source_record_id,'source_identity',r.source_identity));
  end loop;

  update public.import_batches set status='Completed', completed_at=now() where id=p_batch_id;
  v_result := jsonb_build_object('batch_id',p_batch_id,'row_count',v_row_count,'customer_create_count',v_customer_create_count,'customer_reuse_count',v_customer_reuse_count,'order_create_count',v_order_create_count,'order_item_create_count',v_order_item_create_count);
  perform public.complete_command_idempotency('import_historical_batch',p_idempotency_key,v_result);
  return query select p_batch_id,v_row_count,v_customer_create_count,v_customer_reuse_count,v_order_create_count,v_order_item_create_count;
end;
$$;

revoke all on function public.import_historical_batch(uuid,jsonb,text) from public, anon;
grant execute on function public.import_historical_batch(uuid,jsonb,text) to authenticated;
