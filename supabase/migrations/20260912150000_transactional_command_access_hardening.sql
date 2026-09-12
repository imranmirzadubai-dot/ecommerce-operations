begin;

-- Canonical state-changing commands require idempotency keys.
-- Remove legacy overloads so callers cannot bypass the retry contract.
drop function if exists public.create_order(text,text,text,text,numeric,jsonb,text);
drop function if exists public.confirm_order(uuid);
drop function if exists public.cancel_order(uuid);

-- Only authenticated callers may invoke transactional command functions.
revoke all on function public.create_order(text,text,text,text,numeric,jsonb,text,text) from public, anon;
revoke all on function public.confirm_order(uuid,text) from public, anon;
revoke all on function public.cancel_order(uuid,text) from public, anon;
revoke all on function public.cancel_parcel(uuid,text) from public, anon;
revoke all on function public.claim_command_idempotency(text,text,text) from public, anon;
revoke all on function public.complete_command_idempotency(text,text,jsonb) from public, anon;
revoke all on function public.resolve_customer_by_phone(text) from public, anon;

grant execute on function public.create_order(text,text,text,text,numeric,jsonb,text,text) to authenticated;
grant execute on function public.confirm_order(uuid,text) to authenticated;
grant execute on function public.cancel_order(uuid,text) to authenticated;
grant execute on function public.cancel_parcel(uuid,text) to authenticated;
grant execute on function public.claim_command_idempotency(text,text,text) to authenticated;
grant execute on function public.complete_command_idempotency(text,text,jsonb) to authenticated;
grant execute on function public.resolve_customer_by_phone(text) to authenticated;

commit;
