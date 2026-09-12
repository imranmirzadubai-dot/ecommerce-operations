begin;

-- P5-T101: concurrent customer creation regression coverage.
-- The production boundary is the normalized-phone UNIQUE index. The command must
-- resolve the race by catching the losing INSERT's unique_violation and then
-- locking/re-reading the winner in the same transaction.
select plan(10);

select ok(
  (select count(*) = 1
   from pg_indexes
   where schemaname='public'
     and tablename='customers'
     and indexname='uq_customers_normalized_phone'
     and indexdef like '%UNIQUE%'
     and indexdef like '%normalized_phone%'),
  'normalized phone has a database uniqueness boundary'
);

select ok(
  (select count(*) = 1
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public'
     and p.proname='resolve_or_create_customer'
     and pg_get_function_identity_arguments(p.oid)='p_name text, p_phone text, p_address text, p_city text'
     and p.prosecdef),
  'resolve_or_create_customer exists with the protected canonical signature'
);

select ok(
  has_function_privilege('authenticated','public.resolve_or_create_customer(text,text,text,text)','execute'),
  'authenticated callers can execute the customer command'
);

select ok(
  not has_function_privilege('anon','public.resolve_or_create_customer(text,text,text,text)','execute'),
  'anonymous callers cannot execute the customer command'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%unique_violation%'
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='resolve_or_create_customer'),
  'customer creation catches a concurrent normalized-phone uniqueness collision'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%where c.normalized_phone = v_normalized_phone%'
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='resolve_or_create_customer'),
  'the losing concurrent creator re-reads by the same normalized phone'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%for update%'
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='resolve_or_create_customer'),
  'customer identity is locked while the command resolves the race'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%normalize_uae_phone(p_phone)%'
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='resolve_or_create_customer'),
  'the concurrency key is based on canonical UAE phone normalization'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%created boolean%'
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='resolve_or_create_customer'),
  'the command distinguishes creation from resolution after a race'
);

select ok(
  (select count(*) = 0
   from information_schema.role_table_grants
   where grantee='authenticated'
     and table_schema='public'
     and table_name='customers'
     and privilege_type in ('INSERT','UPDATE','DELETE')),
  'browser roles cannot bypass the concurrency-safe command boundary with direct writes'
);

select * from finish();
rollback;
