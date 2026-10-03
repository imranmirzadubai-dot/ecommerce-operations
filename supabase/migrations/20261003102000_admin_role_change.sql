-- P17-T287: trusted admin-only role change command.
-- Roles remain constrained to sales / operations / admin.
-- Self role changes are prohibited and the final active Admin is protected.
-- Uses the existing command idempotency foundation and records a privileged audit event.

create or replace function public.update_admin_user_role(
  p_user_id uuid,
  p_role text,
  p_idempotency_key text,
  p_request_hash text
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
  v_new_role text;
  v_is_new boolean;
  v_status text;
  v_result jsonb;
  v_before jsonb;
  v_after jsonb;
  v_name text;
  v_email text;
  v_role text;
  v_active boolean;
  v_created_at timestamptz;
  v_updated_at timestamptz;
  v_active_admins bigint;
begin
  v_actor := auth.uid();

  if v_actor is null or public.app_role() <> 'admin' then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  if p_user_id is null then
    raise exception using errcode = '22004', message = 'user_id_required';
  end if;

  if p_user_id = v_actor then
    raise exception using errcode = '42501', message = 'self_role_change_forbidden';
  end if;

  v_new_role := lower(nullif(btrim(coalesce(p_role, '')), ''));
  if v_new_role is null then
    raise exception using errcode = '22023', message = 'role_required';
  end if;

  if v_new_role not in ('sales', 'operations', 'admin') then
    raise exception using errcode = '22023', message = 'invalid_role';
  end if;

  select c.is_new, c.status, c.result
    into v_is_new, v_status, v_result
  from public.claim_command_idempotency(
    'update_admin_user_role',
    p_idempotency_key,
    p_request_hash
  ) c;

  if not v_is_new then
    return query
    select
      (v_result->>'user_id')::uuid,
      v_result->>'name',
      v_result->>'email',
      v_result->>'role',
      (v_result->>'active')::boolean,
      (v_result->>'created_at')::timestamptz,
      (v_result->>'updated_at')::timestamptz;
    return;
  end if;

  select
    p.name,
    p.email,
    p.role,
    p.active,
    p.created_at,
    p.updated_at
  into
    v_name,
    v_email,
    v_role,
    v_active,
    v_created_at,
    v_updated_at
  from public.profiles p
  where p.id = p_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'user_not_found';
  end if;

  if v_role = v_new_role then
    v_result := jsonb_build_object(
      'user_id', p_user_id,
      'name', v_name,
      'email', v_email,
      'role', v_role,
      'active', v_active,
      'created_at', v_created_at,
      'updated_at', v_updated_at
    );

    perform public.complete_command_idempotency(
      'update_admin_user_role',
      p_idempotency_key,
      v_result
    );

    return query
    select p_user_id, v_name, v_email, v_role, v_active, v_created_at, v_updated_at;
    return;
  end if;

  if v_role = 'admin' and v_new_role <> 'admin' and v_active then
    select count(*)
      into v_active_admins
    from public.profiles p
    where p.active = true
      and p.role = 'admin';

    if v_active_admins <= 1 then
      raise exception using errcode = '42501', message = 'last_active_admin_protected';
    end if;
  end if;

  v_before := jsonb_build_object('role', v_role);

  update public.profiles
     set role = v_new_role,
         updated_at = now()
   where id = p_user_id
  returning profiles.role, profiles.updated_at
    into v_role, v_updated_at;

  v_after := jsonb_build_object('role', v_role);

  insert into public.audit_logs(
    actor,
    action,
    entity_type,
    entity_id,
    before_data,
    after_data
  ) values (
    v_actor,
    'update_admin_user_role',
    'profile',
    p_user_id,
    v_before,
    v_after
  );

  v_result := jsonb_build_object(
    'user_id', p_user_id,
    'name', v_name,
    'email', v_email,
    'role', v_role,
    'active', v_active,
    'created_at', v_created_at,
    'updated_at', v_updated_at
  );

  perform public.complete_command_idempotency(
    'update_admin_user_role',
    p_idempotency_key,
    v_result
  );

  return query
  select p_user_id, v_name, v_email, v_role, v_active, v_created_at, v_updated_at;
end;
$$;

revoke all on function public.update_admin_user_role(uuid, text, text, text) from public;
grant execute on function public.update_admin_user_role(uuid, text, text, text) to authenticated;
