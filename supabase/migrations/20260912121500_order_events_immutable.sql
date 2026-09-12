begin;

create or replace function public.prevent_order_event_mutation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'order events are immutable; append a new event instead'
    using errcode = '55000';
end;
$$;

revoke all on function public.prevent_order_event_mutation() from public;

drop trigger if exists trg_order_events_immutable on public.order_events;
create trigger trg_order_events_immutable
before update or delete on public.order_events
for each row execute function public.prevent_order_event_mutation();

alter table public.order_events enable row level security;
revoke all on public.order_events from anon;
revoke all on public.order_events from authenticated;
grant select on public.order_events to authenticated;

commit;
