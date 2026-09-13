-- P3-T064: order_events append-only/security verification
-- Fixture-independent catalog assertions; behavior guard can be invoked directly.

select
  exists (
    select 1 from pg_trigger
    where tgrelid = 'public.order_events'::regclass
      and tgname = 'trg_order_events_immutable'
      and not tgisinternal
  ) as immutable_trigger;

select c.relrowsecurity as rls_enabled
from pg_class c
where c.oid = 'public.order_events'::regclass;

select exists (
  select 1 from pg_policies
  where schemaname='public'
    and tablename='order_events'
    and policyname='order_events_authenticated_select'
    and cmd='SELECT'
) as authenticated_select_policy;

select has_table_privilege('authenticated','public.order_events','SELECT') as authenticated_select_grant;
select has_table_privilege('authenticated','public.order_events','INSERT') as authenticated_insert_grant;
select has_table_privilege('authenticated','public.order_events','UPDATE') as authenticated_update_grant;
select has_table_privilege('authenticated','public.order_events','DELETE') as authenticated_delete_grant;
