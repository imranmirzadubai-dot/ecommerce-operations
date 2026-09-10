-- Compatibility names for the command idempotency foundation.
-- Keep one canonical implementation while exposing the command-layer names used by tests and callers.

create or replace function public.claim_command_idempotency(
  p_command_name text,
  p_idempotency_key text,
  p_request_hash text
)
returns table(is_new boolean, status text, result jsonb)
language plpgsql security definer set search_path=pg_catalog,public
as $$
declare v_claim jsonb;
begin
  v_claim := public.begin_command(p_command_name,p_idempotency_key,p_request_hash);
  if coalesce((v_claim->>'completed')::boolean,false) then
    return query select false,'Completed'::text,v_claim->'result';
  end if;
  return query select true,'Started'::text,null::jsonb;
end; $$;
revoke all on function public.claim_command_idempotency(text,text,text) from public,anon,authenticated;
grant execute on function public.claim_command_idempotency(text,text,text) to authenticated;

create or replace function public.complete_command_idempotency(
  p_command_name text,
  p_idempotency_key text,
  p_result jsonb
)
returns void
language plpgsql security definer set search_path=pg_catalog,public
as $$
begin
  perform public.complete_command(p_command_name,p_idempotency_key,p_result);
end; $$;
revoke all on function public.complete_command_idempotency(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.complete_command_idempotency(text,text,jsonb) to authenticated;
