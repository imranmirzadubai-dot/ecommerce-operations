begin;

-- P5-T098: original_amount becomes immutable when an order is confirmed or later.
select plan(10);

select ok(
  (select count(*) = 1 from pg_proc p
   where p.pronamespace='public'::regnamespace
     and p.proname='prevent_confirmed_original_amount_change'),
  'original amount guard trigger function exists'
);

select ok(
  (select count(*) = 1 from pg_trigger t
   join pg_class c on c.oid=t.tgrelid
   join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='orders'
     and t.tgname='trg_orders_original_amount_immutable'
     and not t.tgisinternal),
  'orders original amount immutability trigger exists'
);

select ok(
  (select count(*) = 1 from pg_trigger t
   join pg_class c on c.oid=t.tgrelid
   join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='orders'
     and t.tgname='trg_orders_original_amount_immutable'
     and (t.tgtype & 2) = 2
     and (t.tgtype & 16) = 16),
  'original amount guard is a BEFORE UPDATE trigger'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%new.original_amount is distinct from old.original_amount%'
   from pg_proc p
   where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_original_amount_change'),
  'guard detects an original amount change'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%old.lifecycle_state <> ''Draft''%'
   from pg_proc p
   where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_original_amount_change'),
  'guard applies after the order leaves Draft'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%new.lifecycle_state <> ''Draft''%'
   from pg_proc p
   where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_original_amount_change'),
  'guard prevents changing amount in the same update that confirms the order'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%Original order amount is immutable after confirmation%'
   from pg_proc p
   where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_original_amount_change'),
  'guard raises the locked-amount error'
);

select ok(
  (select pg_get_functiondef(p.oid) like '%return new%'
   from pg_proc p
   where p.pronamespace='public'::regnamespace and p.proname='prevent_confirmed_original_amount_change'),
  'guard preserves unchanged rows'
);

select ok(
  (select has_function_privilege('public','public.prevent_confirmed_original_amount_change()','execute') = false),
  'guard function is not executable by public callers'
);

select ok(
  (select pg_get_triggerdef(t.oid) like '%UPDATE OF original_amount, lifecycle_state ON public.orders%'
   from pg_trigger t
   join pg_class c on c.oid=t.tgrelid
   join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='orders'
     and t.tgname='trg_orders_original_amount_immutable'),
  'trigger covers original amount and lifecycle transition updates'
);

select * from finish();
rollback;
