-- P17-T294: trusted Admin audit-event read boundary.
-- The existing public.audit_logs table remains the write/audit source of truth.
-- This function provides a bounded Admin-only read path without weakening RLS
-- or exposing audit data through direct browser table access.

create or replace function public.admin_list_audit_events(
  p_page integer default 1,
  p_page_size integer default 25,
  p_action text default null,
  p_entity_type text default null,
  p_entity_id uuid default null
)
returns table(
  id uuid,
  actor uuid,
  action text,
  entity_type text,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  request_id text,
  occurred_at timestamptz,
  total_count bigint
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_page integer := coalesce(p_page, 1);
  v_page_size integer := coalesce(p_page_size, 25);
  v_action text := nullif(btrim(coalesce(p_action, '')), '');
  v_entity_type text := nullif(btrim(coalesce(p_entity_type, '')), '');
  v_offset integer;
begin
  if auth.uid() is null or public.app_role() <> 'admin' then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  if v_page < 1 or v_page_size < 1 or v_page_size > 100 then
    raise exception using errcode = '22023', message = 'invalid_pagination';
  end if;

  v_offset := (v_page - 1) * v_page_size;

  return query
  select
    a.id,
    a.actor,
    a.action,
    a.entity_type,
    a.entity_id,
    a.before_data,
    a.after_data,
    a.request_id,
    a.occurred_at,
    count(*) over() as total_count
  from public.audit_logs a
  where (v_action is null or a.action = v_action)
    and (v_entity_type is null or a.entity_type = v_entity_type)
    and (p_entity_id is null or a.entity_id = p_entity_id)
  order by a.occurred_at desc, a.id desc
  limit v_page_size
  offset v_offset;
end;
$$;

create index if not exists idx_audit_logs_occurred_at
  on public.audit_logs(occurred_at desc, id desc);

revoke all on function public.admin_list_audit_events(integer, integer, text, text, uuid) from public;
grant execute on function public.admin_list_audit_events(integer, integer, text, text, uuid) to authenticated;
