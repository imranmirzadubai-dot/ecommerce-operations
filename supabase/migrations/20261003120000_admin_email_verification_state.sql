-- P17-T290: trusted Admin read path for Supabase Auth invitation / email state.
-- Supabase Auth remains the sole identity system. Auth state is read server-side
-- through a narrow SECURITY DEFINER function and is never exposed by direct
-- client access to auth.users.

create or replace function public.admin_get_user_auth_state(
  p_user_id uuid
)
returns table(
  user_id uuid,
  email text,
  invited_at timestamptz,
  confirmation_sent_at timestamptz,
  email_confirmed_at timestamptz,
  confirmed_at timestamptz,
  last_sign_in_at timestamptz,
  email_verified boolean,
  invitation_pending boolean
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_invited_at timestamptz;
  v_confirmation_sent_at timestamptz;
  v_email_confirmed_at timestamptz;
  v_confirmed_at timestamptz;
  v_last_sign_in_at timestamptz;
  v_email text;
begin
  if auth.uid() is null or public.app_role() <> 'admin' then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  if p_user_id is null then
    raise exception using errcode = '22004', message = 'user_id_required';
  end if;

  select
    u.email,
    u.invited_at,
    u.confirmation_sent_at,
    u.email_confirmed_at,
    u.confirmed_at,
    u.last_sign_in_at
  into
    v_email,
    v_invited_at,
    v_confirmation_sent_at,
    v_email_confirmed_at,
    v_confirmed_at,
    v_last_sign_in_at
  from auth.users u
  where u.id = p_user_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'user_not_found';
  end if;

  return query
  select
    p_user_id,
    v_email,
    v_invited_at,
    v_confirmation_sent_at,
    v_email_confirmed_at,
    v_confirmed_at,
    v_last_sign_in_at,
    (v_email_confirmed_at is not null),
    (v_invited_at is not null and v_email_confirmed_at is null);
end;
$$;

revoke all on function public.admin_get_user_auth_state(uuid) from public;
grant execute on function public.admin_get_user_auth_state(uuid) to authenticated;
