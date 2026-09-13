-- P3-T073 verification: all application SECURITY DEFINER functions pin
-- search_path to pg_catalog, public.
select p.proname,
       pg_get_function_identity_arguments(p.oid) as args,
       p.prosecdef as security_definer,
       coalesce(array_to_string(p.proconfig, ','), '') as config
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'app_role','create_order','confirm_order','cancel_order','cancel_parcel',
    'claim_command_idempotency','complete_command_idempotency','resolve_customer_by_phone'
  )
order by p.proname, args;
