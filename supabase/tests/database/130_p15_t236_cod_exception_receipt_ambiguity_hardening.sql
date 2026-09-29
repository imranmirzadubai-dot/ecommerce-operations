begin;
select plan(3);

select ok(
  (select position('from public.financial_adjustments fa' in pg_get_functiondef(p.oid)) > 0
   and position('where fa.cod_receipt_id = v_receipt.id' in pg_get_functiondef(p.oid)) > 0
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.prokind='f' and p.proname='resolve_cod_exception'),
  'COD exception resolution qualifies financial adjustment receipt lookup'
);

select ok(
  (select position('where cod_receipt_id = v_receipt.id' in pg_get_functiondef(p.oid)) = 0
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.prokind='f' and p.proname='resolve_cod_exception'),
  'COD exception resolution has no unqualified cod_receipt_id lookup'
);

select ok(
  (select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public'
     and p.proname='resolve_cod_exception'
     and pg_get_function_identity_arguments(p.oid)='p_cod_receipt_id uuid, p_reason text, p_idempotency_key text'),
  'COD exception resolution canonical signature retained'
);

select * from finish();
rollback;