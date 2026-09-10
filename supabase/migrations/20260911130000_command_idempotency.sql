-- E-Commerce Operations MVP v4.0
-- Command idempotency foundation.
-- State-changing commands must use this table to make retries deterministic.

create table if not exists public.command_idempotency (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id) on delete restrict,
  command_name text not null,
  idempotency_key text not null,
  request_hash text not null,
  status text not null default 'Started' check (status in ('Started','Completed')),
  result jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (actor_id, command_name, idempotency_key)
);

create index if not exists idx_command_idempotency_created_at
  on public.command_idempotency(created_at);

alter table public.command_idempotency enable row level security;
revoke all on table public.command_idempotency from anon, authenticated;

create or replace function public.claim_command_idempotency(
  p_command_name text,
  p_idempotency_key text,
  p_request_hash text
)
returns table(is_new boolean, status text, result jsonb)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid;
  v_status text;
  v_result jsonb;
  v_existing_hash text;
begin
  v_actor_id := auth.uid();
  if v_actor_id is null or public.app_role() is null then
    raise exception using errcode='42501', message='Authentication required';
  end if;
  if btrim(coalesce(p_command_name,''))='' then
    raise exception using errcode='22023', message='Command name is required';
  end if;
  if btrim(coalesce(p_idempotency_key,''))='' then
    raise exception using errcode='22023', message='Idempotency key is required';
  end if;
  if btrim(coalesce(p_request_hash,''))='' then
    raise exception using errcode='22023', message='Request hash is required';
  end if;

  insert into public.command_idempotency(actor_id, command_name, idempotency_key, request_hash)
  values(v_actor_id, p_command_name, p_idempotency_key, p_request_hash)
  on conflict (actor_id, command_name, idempotency_key) do nothing;

  select c.request_hash, c.status, c.result
    into v_existing_hash, v_status, v_result
  from public.command_idempotency c
  where c.actor_id=v_actor_id
    and c.command_name=p_command_name
    and c.idempotency_key=p_idempotency_key
  for update;

  if v_existing_hash <> p_request_hash then
    raise exception using errcode='22023', message='Idempotency key was already used with a different request';
  end if;

  if v_status='Completed' then
    return query select false, v_status, v_result;
  end if;

  return query select true, v_status, v_result;
end; $$;

revoke all on function public.claim_command_idempotency(text,text,text) from public;
grant execute on function public.claim_command_idempotency(text,text,text) to authenticated;

create or replace function public.complete_command_idempotency(
  p_command_name text,
  p_idempotency_key text,
  p_result jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null or public.app_role() is null then
    raise exception using errcode='42501', message='Authentication required';
  end if;

  update public.command_idempotency
     set status='Completed', result=p_result, completed_at=now()
   where actor_id=auth.uid()
     and command_name=p_command_name
     and idempotency_key=p_idempotency_key;

  if not found then
    raise exception using errcode='P0002', message='Idempotency record not found';
  end if;
end; $$;

revoke all on function public.complete_command_idempotency(text,text,jsonb) from public;
grant execute on function public.complete_command_idempotency(text,text,jsonb) to authenticated;
