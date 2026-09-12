begin;

-- T059: delivery outcomes are permanent event history.
-- Outcomes may be appended, but existing history cannot be updated or deleted,
-- including by privileged database roles. Corrections are represented by a new
-- outcome row rather than mutation of historical evidence.

create or replace function public.prevent_delivery_outcome_mutation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'delivery outcomes are immutable; append a new outcome instead'
    using errcode = '55000';
end;
$$;

revoke all on function public.prevent_delivery_outcome_mutation() from public;

drop trigger if exists trg_delivery_outcomes_immutable on public.delivery_outcomes;
create trigger trg_delivery_outcomes_immutable
before update or delete on public.delivery_outcomes
for each row execute function public.prevent_delivery_outcome_mutation();

alter table public.delivery_outcomes enable row level security;
revoke all on public.delivery_outcomes from anon;
revoke all on public.delivery_outcomes from authenticated;
grant select on public.delivery_outcomes to authenticated;

commit;
