begin;

-- P11-T173: make COD receipt state authoritative at the database boundary.
-- Exact collection is Received; any variance between the authoritative
-- expected snapshot and collected amount is Exception.

create or replace function public.enforce_cod_receipt_variance_state()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.expected_amount_snapshot <> new.received_amount then
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
before insert on public.cod_receipts
for each row
execute function public.enforce_cod_receipt_variance_state();

commit;
