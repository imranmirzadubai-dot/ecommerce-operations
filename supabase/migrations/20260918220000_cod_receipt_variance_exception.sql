begin;

-- P11-T173: a COD receipt is Exception whenever collected amount differs
-- from the authoritative expected-amount snapshot. Exact matches remain
-- Received. The state is derived in the database so clients cannot suppress
-- or misclassify a financial variance.

create or replace function public.enforce_cod_receipt_variance_state()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.received_amount <> new.expected_amount_snapshot then
    new.state := 'Exception';
  else
    new.state := 'Received';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_cod_receipt_variance_state() from public, anon, authenticated;

drop trigger if exists trg_cod_receipt_variance_state on public.cod_receipts;
create trigger trg_cod_receipt_variance_state
before insert or update of expected_amount_snapshot, received_amount, state
on public.cod_receipts
for each row
execute function public.enforce_cod_receipt_variance_state();

commit;
