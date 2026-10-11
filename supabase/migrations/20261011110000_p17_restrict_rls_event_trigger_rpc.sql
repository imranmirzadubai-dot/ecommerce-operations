begin;

-- Supabase installs this event-trigger function in managed database setup.
-- Local migration-test databases may not include that managed function, so
-- conditionally harden it when present. PostgreSQL invokes the registered
-- event-trigger function through its registration, not through client RPC.
do $migration$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke execute on function public.rls_auto_enable() from public';
    execute 'revoke execute on function public.rls_auto_enable() from anon';
    execute 'revoke execute on function public.rls_auto_enable() from authenticated';
  end if;
end
$migration$;

commit;
