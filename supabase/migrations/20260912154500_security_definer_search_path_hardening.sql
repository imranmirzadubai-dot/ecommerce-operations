begin;

-- P3-T073: every SECURITY DEFINER application function must pin its
-- resolution path so caller-controlled search_path cannot redirect objects.

alter function public.app_role() set search_path = pg_catalog, public;
alter function public.create_order(text,text,text,text,numeric,jsonb,text,text) set search_path = pg_catalog, public;
alter function public.confirm_order(uuid,text) set search_path = pg_catalog, public;
alter function public.cancel_order(uuid,text) set search_path = pg_catalog, public;
alter function public.cancel_parcel(uuid,text) set search_path = pg_catalog, public;
alter function public.claim_command_idempotency(text,text,text) set search_path = pg_catalog, public;
alter function public.complete_command_idempotency(text,text,jsonb) set search_path = pg_catalog, public;
alter function public.resolve_customer_by_phone(text) set search_path = pg_catalog, public;

commit;
