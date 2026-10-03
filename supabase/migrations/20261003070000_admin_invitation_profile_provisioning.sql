-- P17-T282: trusted profile provisioning after Supabase Auth invitation.
-- Auth identity creation remains in the trusted server boundary; this function only
-- links an already-created auth.users identity to public.profiles.

create or replace function public.provision_invited_profile(
  p_user_id uuid,
  p_name text,
  p_role text
)
returns public.profiles
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid;
  v_email text;
  v_profile public.profiles;
begin
  v_actor := auth.uid();

  if v_actor is null or public.app_role() <> 'admin' then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  if p_user_id is null then
    raise exception using errcode = '22023', message = 'user_id_required';
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception using errcode = '22023', message = 'name_required';
  end if;

  if p_role is null or p_role not in ('sales','operations','admin') then
    raise exception using errcode = '22023', message = 'invalid_role';
  end if;

  select u.email
    into v_email
  from auth.users u
  where u.id = p_user_id;

  if v_email is null then
    raise exception using errcode = '22023', message = 'auth_user_not_found';
  end if;

  if exists (select 1 from public.profiles p where p.id = p_user_id) then
    raise exception using errcode = '23505', message = 'profile_already_exists';
  end if;

  insert into public.profiles (id, name, email, role, active)
  values (p_user_id, btrim(p_name), lower(btrim(v_email)), p_role, true)
  returning * into v_profile;

  insert into public.audit_logs (
    actor, action, entity_type, entity_id, before_data, after_data
  ) values (
    v_actor,
    'user_invited_profile_provisioned',
    'profile',
    v_profile.id,
    null,
    jsonb_build_object(
      'id', v_profile.id,
      'name', v_profile.name,
      'email', v_profile.email,
      'role', v_profile.role,
      'active', v_profile.active
    )
  );

  return v_profile;
end;
$$;

revoke all on function public.provision_invited_profile(uuid, text, text) from public;
grant execute on function public.provision_invited_profile(uuid, text, text) to authenticated;
