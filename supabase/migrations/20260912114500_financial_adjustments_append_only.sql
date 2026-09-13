begin;

-- Financial adjustments are append-only business history. Preserve the
-- authoritative numeric contract and prevent mutation/deletion at the DB edge.
alter table public.financial_adjustments
  add constraint financial_adjustments_delta_amount_precision
  check (delta_amount = round(delta_amount, 2));

alter table public.financial_adjustments
  enable row level security;

revoke all on public.financial_adjustments from anon;
revoke all on public.financial_adjustments from authenticated;
grant select on public.financial_adjustments to authenticated;

drop trigger if exists trg_financial_adjustments_immutable on public.financial_adjustments;
create or replace function public.prevent_financial_adjustment_mutation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'financial adjustments are append-only; create a new adjustment instead'
    using errcode = '55000';
end;
$$;
revoke all on function public.prevent_financial_adjustment_mutation() from public;
create trigger trg_financial_adjustments_immutable
before update or delete on public.financial_adjustments
for each row execute function public.prevent_financial_adjustment_mutation();

commit;
