-- Admin invitation/profile provisioning contract.
begin;

select plan(12);

select ok(exists (
  select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'provision_invited_profile'
    and pg_get_function_identity_arguments(p.oid) =
      'p_user_id uuid, p_name text, p_role text'
), 'provision_invited_profile exists with the locked signature');

select ok((select prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'provision_invited_profile'
    and pg_get_function_identity_arguments(p.oid) =
      'p_user_id uuid, p_name text, p_role text'),
  'profile provisioning is SECURITY DEFINER');

select ok((select proconfig @> array['search_path=pg_catalog, public'] from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'provision_invited_profile'
    and pg_get_function_identity_arguments(p.oid) =
      'p_user_id uuid, p_name text, p_role text'),
  'profile provisioning has a pinned search_path');

select ok(has_function_privilege(
  'authenticated', 'public.provision_invited_profile(uuid,text,text)', 'EXECUTE'
), 'authenticated can reach the provisioning command boundary');

select ok(not has_function_privilege(
  'anon', 'public.provision_invited_profile(uuid,text,text)', 'EXECUTE'
), 'anon cannot execute the provisioning command');

select ok(pg_get_functiondef((
  select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'provision_invited_profile'
    and pg_get_function_identity_arguments(p.oid) =
      'p_user_id uuid, p_name text, p_role text'
)) like '%public.app_role() <> ''admin''%',
  'provisioning requires an active Admin application role');

select ok(pg_get_functiondef((
  select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'provision_invited_profile'
    and pg_get_function_identity_arguments(p.oid) =
      'p_user_id uuid, p_name text, p_role text'
)) like '%auth.users%',
  'provisioning verifies the Auth identity exists');

select ok(pg_get_functiondef((
  select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'provision_invited_profile'
    and pg_get_function_identity_arguments(p.oid) =
      'p_user_id uuid, p_name text, p_role text'
)) like '%profile_already_exists%',
  'provisioning rejects conflicting existing profiles');

select ok(pg_get_functiondef((
  select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'provision_invited_profile'
    and pg_get_function_identity_arguments(p.oid) =
      'p_user_id uuid, p_name text, p_role text'
)) like '%''sales'', ''operations'', ''admin''%',
  'provisioning validates the application role contract');

select ok(pg_get_functiondef((
  select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'provision_invited_profile'
    and pg_get_function_identity_arguments(p.oid) =
      'p_user_id uuid, p_name text, p_role text'
)) like '%provision_invited_profile%',
  'provisioning records a dedicated audit action');

select ok(pg_get_functiondef((
  select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'provision_invited_profile'
    and pg_get_function_identity_arguments(p.oid) =
      'p_user_id uuid, p_name text, p_role text'
)) like '%for update%',
  'existing profile lookup is locked for retry-safe provisioning');

select ok(pg_get_functiondef((
  select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'provision_invited_profile'
    and pg_get_function_identity_arguments(p.oid) =
      'p_user_id uuid, p_name text, p_role text'
)) like '%auth_user_not_found%',
  'unknown Auth identities are rejected');

select * from finish();
rollback;
