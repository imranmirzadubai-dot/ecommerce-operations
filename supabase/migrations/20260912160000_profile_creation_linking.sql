begin;

-- P4-T080: controlled profile creation/linking.
-- The profile is explicitly linked to an existing auth.users identity. Role is supplied
-- by the authenticated Admin caller; no client-controlled metadata is trusted.
create or replace function public.create_profile(
  p_user_id uuid,
  p_name text,
  p_role text
)
returns public.profiles
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_profile public.profiles;
  v_email text;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  if public.app_role() <> 'admin' then
    raise exception 'admin_role_required' using errcode = '42501';
  end if;

  if p_user_id is null or p_name is null or btrim(p_name) = '' then
    raise exception 'profile_identity_required' using errcode = '22023';
  end if;

  if p_role is null or p_role not in ('sales','operations','admin') then
    raise exception 'invalid_application_role' using errcode = '22023';
  end if;

  select u.email into v_email
  from auth.users u
  where u.id = p_user_id;

  if v_email is null then
    raise exception 'auth_user_not_found' using errcode = '22023';
  end if;

  insert into public.profiles (id, name, email, role, active)
  values (p_user_id, btrim(p_name), v_email, p_role, true)
  returning * into v_profile;

  return v_profile;
end;
$$;

revoke all on function public.create_profile(uuid,text,text) from public, anon;
grant execute on function public.create_profile(uuid,text,text) to authenticated;

commit;
