begin;

-- Remove the legacy 7-parameter overload after restoring the authoritative
-- idempotent 8-parameter create_order contract.
drop function if exists public.create_order(text,text,text,text,numeric,jsonb,text);

commit;
