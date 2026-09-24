begin;

select plan(8);

select has_function(
  'public',
  'create_order',
  ARRAY['text','text','text','text','numeric','jsonb','text','text'],
  'canonical create_order function exists'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.create_order(text,text,text,text,numeric,jsonb,text,text)',
    'EXECUTE'
  ),
  'authenticated can execute create_order'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.resolve_customer_by_phone(text)',
    'EXECUTE'
  ),
  'authenticated can execute customer phone lookup'
);

select ok(
  position('normalize_uae_phone' in lower(pg_get_functiondef(
    'public.create_order(text,text,text,text,numeric,jsonb,text,text)'::regprocedure
  ))) > 0,
  'create_order uses canonical UAE phone normalization'
);

select ok(
  position('returning public.orders.id, public.orders.order_number' in lower(pg_get_functiondef(
    'public.create_order(text,text,text,text,numeric,jsonb,text,text)'::regprocedure
  ))) > 0,
  'create_order qualifies order_number in INSERT RETURNING'
);

select ok(
  position('normalize_uae_phone' in lower(pg_get_functiondef(
    'public.resolve_customer_by_phone(text)'::regprocedure
  ))) > 0,
  'customer phone lookup uses canonical UAE phone normalization'
);

select is(
  public.normalize_uae_phone('0581518383'),
  '+971581518383',
  'local UAE mobile input resolves to canonical E.164 form'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.resolve_customer_by_phone(text)',
    'EXECUTE'
  ),
  'anonymous customer phone lookup remains blocked'
);

select * from finish();
rollback;
