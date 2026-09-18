-- P11-T167 access hardening: the browser write-privilege regression migration
-- revoke broad function access explicitly from PUBLIC and anon; retain the authenticated RPC grant.
revoke all on function public.create_cod_obligation(uuid,text) from public, anon;
grant execute on function public.create_cod_obligation(uuid,text) to authenticated;
