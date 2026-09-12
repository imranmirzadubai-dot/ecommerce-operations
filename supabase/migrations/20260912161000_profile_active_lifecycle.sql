begin;

-- P4-T082: controlled application-profile activation lifecycle.
-- The Auth identity is retained; this command controls the linked application profile.
create or replace function public.set_profile_active(
  p_user_id uuid,
  p_active boolean
)
returns public.profiles
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_profile public.profiles;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  if public.app_role() <> 'admin' then
    raise exception 'admin_role_required' using errcode = '42501';
  end if;

  if p_user_id is null or p_active is null then
    raise exception 'profile_status_required' using errcode = '22023';
  end if;

  update public.profiles
  set active = p_active,
      updated_at = now()
  where id = p_user_id
  returning * into v_profile;

  if v_profile.id is null then
    raise exception 'profile_not_found' using errcode = '22023';
  end if;

  return v_profile;
end;
$$;

revoke all on function public.set_profile_active(uuid,boolean) from public, anon;
grant execute on function public.set_profile_active(uuid,boolean) to authenticated;

commit;
