-- P17-T285: admin-only user detail read boundary.
-- This function is intentionally read-only and does not weaken profiles RLS.

create or replace function public.admin_get_profile(
  p_user_id uuid
)
returns table (
  id uuid,
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
begin
  if auth.uid() is null or public.app_role() <> 'admin' then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  if p_user_id is null then
    raise exception using errcode = '22004', message = 'user_id_required';
  end if;

  return query
  select
    p.id,
    p.name,
    p.email,
    p.role,
    p.active,
    p.created_at,
    p.updated_at
  from public.profiles p
  where p.id = p_user_id;
end;
$$;

revoke all on function public.admin_get_profile(uuid) from public;
grant execute on function public.admin_get_profile(uuid) to authenticated;
