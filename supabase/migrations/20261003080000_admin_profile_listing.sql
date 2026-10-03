-- P17-T284: admin-only user listing/search/filter boundary.
-- This function is intentionally read-only and does not weaken profiles RLS.

create or replace function public.admin_list_profiles(
  p_search text default null,
  p_role text default null,
  p_active boolean default null,
  p_limit integer default 25,
  p_offset integer default 0
)
returns table (
  id uuid,
  name text,
  email text,
  role text,
  active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  total_count bigint
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 25), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if auth.uid() is null or public.app_role() <> 'admin' then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  if p_role is not null and p_role not in ('sales', 'operations', 'admin') then
    raise exception using errcode = '22023', message = 'invalid_role';
  end if;

  return query
  select
    p.id,
    p.name,
    p.email,
    p.role,
    p.active,
    p.created_at,
    p.updated_at,
    count(*) over () as total_count
  from public.profiles p
  where (v_search is null
         or position(lower(v_search) in lower(coalesce(p.name, ''))) > 0
         or position(lower(v_search) in lower(coalesce(p.email, ''))) > 0)
    and (p_role is null or p.role = p_role)
    and (p_active is null or p.active = p_active)
  order by lower(coalesce(p.name, '')), lower(coalesce(p.email, '')), p.id
  limit v_limit
  offset v_offset;
end;
$$;

revoke all on function public.admin_list_profiles(text, text, boolean, integer, integer) from public;
grant execute on function public.admin_list_profiles(text, text, boolean, integer, integer) to authenticated;
