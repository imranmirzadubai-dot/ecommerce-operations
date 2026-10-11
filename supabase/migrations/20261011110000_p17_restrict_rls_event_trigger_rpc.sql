begin;

-- Event-trigger functions are invoked by PostgreSQL's event-trigger mechanism,
-- not through the PostgREST RPC surface. Remove direct execution grants while
-- preserving the registered ensure_rls event trigger.
revoke execute on function public.rls_auto_enable() from public;
revoke execute on function public.rls_auto_enable() from anon;
revoke execute on function public.rls_auto_enable() from authenticated;

commit;
