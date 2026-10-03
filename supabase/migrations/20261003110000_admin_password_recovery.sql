-- P17-T289: trusted admin password-recovery authorization boundary.
-- Supabase Auth remains the sole identity/password system. This function only authorizes
-- the recovery request, returns the target profile email, and records the privileged event.
-- The Worker performs the Auth recovery-email request using the server-only secret key.

create or replace function public.prepare_admin_password_recovery(
  p_user_id uuid
)
returns table(
  user_id uuid,
  email text,
  active boolean,
  role text
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_email text;
  v_active boolean;
  v_role text;
begin
  if auth.uid() is null or public.app_role() <> 'admin' then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  if p_user_id is null then
    raise exception using errcode = '22004', message = 'user_id_required';
  end if;

  select p.email, p.active, p.role
    into v_email, v_active, v_role
  from public.profiles p
  where p.id = p_user_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'user_not_found';
  end if;

  if v_email is null or btrim(v_email) = '' then
    raise exception using errcode = '22023', message = 'user_email_unavailable';
  end if;

  insert into public.audit_logs(
    actor,
    action,
    entity_type,
    entity_id,
    before_data,
    after_data
  ) values (
    auth.uid(),
    'admin_password_recovery_requested',
    'profile',
    p_user_id,
    null,
    jsonb_build_object('active', v_active, 'role', v_role)
  );

  return query select p_user_id, v_email, v_active, v_role;
end;
$$;

revoke all on function public.prepare_admin_password_recovery(uuid) from public;
grant execute on function public.prepare_admin_password_recovery(uuid) to authenticated;
