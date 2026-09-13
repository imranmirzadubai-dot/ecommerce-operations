begin;

-- P5-T094: Order item entry contract.
-- Verify the authoritative command accepts description + positive integer quantity
-- and persists those values into the Order Item model.
select plan(10);

select ok(
  (select pg_get_functiondef(p.oid) like '%v_description:=nullif%'
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_order'),
  'create_order requires a non-empty item description'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%coalesce(v_item->>''quantity'','''') !~ ''^\\\\d+$''%'
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_order'),
  'create_order rejects non-integer quantity text'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%if v_quantity<=0 then%'
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_order'),
  'create_order rejects zero or negative quantities'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%v_quantity:=(v_item->>''quantity'')::integer%'
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_order'),
  'create_order stores quantity as integer'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%insert into public.order_items(order_id,line_no,description,quantity)%'
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_order'),
  'create_order persists description and integer quantity on order_items'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%for v_item in select value from jsonb_array_elements(p_items) loop%'
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_order'),
  'create_order supports multiple order-item rows'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%v_line_no:=v_line_no+1%'
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_order'),
  'create_order assigns deterministic line numbers'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%format(''Invalid order item at line %s'',v_line_no)%'
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_order'),
  'create_order returns an explicit item-line validation error'
);

select ok(
  (select data_type = 'integer'
   from information_schema.columns
   where table_schema='public' and table_name='order_items' and column_name='quantity'),
  'order_items.quantity is an INTEGER column'
);

select ok(has_function_privilege('authenticated','public.create_order(text,text,text,text,numeric,jsonb,text,text)','execute'), 'authenticated callers retain the item-entry command boundary');

select * from finish();
rollback;
