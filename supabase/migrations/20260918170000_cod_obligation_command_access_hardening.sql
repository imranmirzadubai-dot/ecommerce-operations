-- P11-T167 access hardening: the browser write-privilege regression migration
-- revokes broad table writes only; this command must retain its explicit RPC grant.
revoke all on function public.create_cod_obligation(uuid,text) from public;
grant execute on function public.create_cod_obligation(uuid,text) to authenticated;
