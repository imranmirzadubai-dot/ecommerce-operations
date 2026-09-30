do $$
declare
  v_name text;
  v_count integer;
begin
  for v_name in
    select table_name from information_schema.views
    where table_schema='public'
      and table_name in ('order_delivery_rto_summary','order_fulfillment_summary','order_item_rto_reconciliation','order_item_terminal_reconciliation')
  loop
    if not ('security_invoker=true' = any(coalesce((
      select c.reloptions from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=v_name
    ), '{}'))) then
      raise exception 'Legacy report view % is not security_invoker', v_name;
    end if;
  end loop;

  select count(*) into v_count
  from information_schema.role_table_grants
  where table_schema='public'
    and table_name in ('order_delivery_rto_summary','order_fulfillment_summary','order_item_rto_reconciliation','order_item_terminal_reconciliation')
    and grantee='authenticated'
    and privilege_type <> 'SELECT';

  if v_count <> 0 then
    raise exception 'Legacy report views retain non-SELECT authenticated grants: %', v_count;
  end if;

  select count(*) into v_count
  from information_schema.role_table_grants
  where table_schema='public'
    and table_name in ('order_delivery_rto_summary','order_fulfillment_summary','order_item_rto_reconciliation','order_item_terminal_reconciliation')
    and grantee='anon';

  if v_count <> 0 then
    raise exception 'Legacy report views expose privileges to anon: %', v_count;
  end if;
end $$;