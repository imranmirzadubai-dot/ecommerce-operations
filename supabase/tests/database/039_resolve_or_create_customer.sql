begin;

-- P5-T091: resolve-or-create customer command regression coverage.
select plan(14);

select ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'
    and pg_get_function_identity_arguments(p.oid)='p_name text, p_phone text, p_address text, p_city text'
    and p.prosecdef), 'resolve_or_create_customer exists with the canonical signature and SECURITY DEFINER');

select ok(has_function_privilege('authenticated','public.resolve_or_create_customer(text,text,text,text)','execute'), 'authenticated role can execute resolve_or_create_customer');
select ok(has_function_privilege('anon','public.resolve_or_create_customer(text,text,text,text)','execute') = false, 'anonymous callers cannot execute resolve_or_create_customer');
select ok((select pg_get_functiondef(p.oid) like '%public.app_role() not in (''sales'',''operations'',''admin'')%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'), 'resolve-or-create requires an approved active application role');
select ok((select pg_get_functiondef(p.oid) like '%public.normalize_uae_phone(p_phone)%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'), 'resolve-or-create uses the canonical UAE phone normalization function');
select ok((select pg_get_functiondef(p.oid) like '%where c.normalized_phone = v_normalized_phone%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'), 'customer resolution is keyed by normalized phone');
select ok((select pg_get_functiondef(p.oid) like '%unique_violation%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'), 'concurrent customer creation is handled through the normalized-phone uniqueness boundary');
select ok((select pg_get_functiondef(p.oid) like '%insert into public.audit_logs%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'), 'customer resolution/creation is audit logged');
select ok((select pg_get_functiondef(p.oid) like '%created boolean%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'), 'command reports whether the customer was created');
select ok((select pg_get_functiondef(p.oid) like '%Valid UAE phone is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'), 'invalid phone input is rejected at the command boundary');
select ok((select pg_get_functiondef(p.oid) like '%Customer name is required%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'), 'blank customer names are rejected');
select ok((select pg_get_functiondef(p.oid) like '%for update%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'), 'existing customer identity is locked during the transaction');
select ok((select count(*) = 0 from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public' and privilege_type in ('INSERT','UPDATE','DELETE')), 'browser roles retain no direct customer table writes');
select ok((select pg_get_functiondef(p.oid) like '%revoke all on function public.resolve_or_create_customer(text,text,text,text) from public, anon%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='resolve_or_create_customer'), 'anonymous/public function execution is explicitly revoked');

select * from finish();
rollback;
