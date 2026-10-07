-- Admin user invitation/profile provisioning boundary.
-- Supabase Auth creates the identity; this trusted command creates the application profile.
-- The command is idempotent for an already-provisioned matching profile.

create or replace function public.provision_invited_profile(
  p_user_id uuid,
  p_name text,
  p_role text
)
returns table(
  user_id uuid,
  name text,
  email text,
  role text,
  active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid;
  v_name text;
  v_role text;
  v_email text;
  v_existing_name text;
  v_existing_email text;
  v_existing_role text;
  v_existing_active boolean;
  v_created_at timestamptz;
  v_updated_at timestamptz;
begin
  v_actor := auth.uid();

  if v_actor is null or public.app_role() <> 'admin' then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  if p_user_id is null then
    raise exception using errcode = '22004', message = 'user_id_required';
  end if;

  v_name := btrim(coalesce(p_name, ''));
  if v_name = '' or length(v_name) > 200 then
    raise exception using errcode = '22023', message = 'invalid_name';
  end if;

  v_role := lower(btrim(coalesce(p_role, '')));
  if v_role not in ('sales', 'operations', 'admin') then
    raise exception using errcode = '22023', message = 'invalid_role';
  end if;

  select u.email into v_email
  from auth.users u
  where u.id = p_user_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'auth_user_not_found';
  end if;

  if v_email is null or btrim(v_email) = '' then
    raise exception using errcode = '22023', message = 'user_email_unavailable';
  end if;

  select p.name, p.email, p.role, p.active, p.created_at, p.updated_at
    into v_existing_name, v_existing_email, v_existing_role,
         v_existing_active, v_created_at, v_updated_at
  from public.profiles p
  where p.id = p_user_id
  for update;

  if found then
    if v_existing_name = v_name
       and v_existing_email = v_email
       and v_existing_role = v_role
       and v_existing_active = true then
      return query select p_user_id, v_existing_name, v_existing_email,
        v_existing_role, v_existing_active, v_created_at, v_updated_at;
      return;
    end if;

    raise exception using errcode = '23505', message = 'profile_already_exists';
  end if;

  insert into public.profiles(id, name, email, role, active)
  values (p_user_id, v_name, v_email, v_role, true)
  returning profiles.created_at, profiles.updated_at
    into v_created_at, v_updated_at;

  insert into public.audit_logs(
    actor, action, entity_type, entity_id, before_data, after_data
  ) values (
    v_actor,
    'provision_invited_profile',
    'profile',
    p_user_id,
    null,
    jsonb_build_object(
      'name', v_name,
      'email', v_email,
      'role', v_role,
      'active', true
    )
  );

  return query select p_user_id, v_name, v_email, v_role, true,
    v_created_at, v_updated_at;
end;
$$;

revoke all on function public.provision_invited_profile(uuid, text, text) from public;
grant execute on function public.provision_invited_profile(uuid, text, text) to authenticated;
