do $$
declare v_def text;
begin
  select pg_get_functiondef('public.import_historical_batch(uuid,jsonb,text)'::regprocedure)
    into v_def;
  if position($q$values(v_customer_id, v_order_date, 'AED', v_amount, 'Completed', 'Historical import; source row '$q$ in v_def)=0
     or position($q$v_order_item_create_count := v_order_item_create_count + 1;

    insert into public.order_events$q$ in v_def)=0 then
    raise exception 'P15-T239 migration guard failed for import_historical_batch lifecycle ordering';
  end if;

  v_def := replace(v_def,
    $q$values(v_customer_id, v_order_date, 'AED', v_amount, 'Completed', 'Historical import; source row '||r.source_row_number::text, v_actor_id)$q$,
    $q$values(v_customer_id, v_order_date, 'AED', v_amount, 'Draft', 'Historical import; source row '||r.source_row_number::text, v_actor_id)$q$);

  v_def := replace(v_def,
    $q$v_order_item_create_count := v_order_item_create_count + 1;

    insert into public.order_events$q$,
    $q$v_order_item_create_count := v_order_item_create_count + 1;

    update public.orders
    set lifecycle_state = 'Completed'
    where id = v_order_id;

    insert into public.order_events$q$);
  execute v_def;
end $$;
