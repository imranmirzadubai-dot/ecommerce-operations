begin;

-- P11-T175: original COD receipt history is immutable.
-- Corrections belong in append-only financial adjustments; the receipt row itself
-- must never be updated or deleted after authoritative recording.

create or replace function public.prevent_cod_receipt_mutation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Original COD receipt is immutable; use an append-only financial adjustment';
end;
$$;

revoke all on function public.prevent_cod_receipt_mutation() from public;
revoke all on function public.prevent_cod_receipt_mutation() from anon;
grant execute on function public.prevent_cod_receipt_mutation() to authenticated;

drop trigger if exists cod_receipts_immutable_update on public.cod_receipts;
create trigger cod_receipts_immutable_update
before update or delete on public.cod_receipts
for each row
execute function public.prevent_cod_receipt_mutation();

-- Keep the application surface read-only at table level. Transactional commands
-- remain the only state-changing path, and this explicitly documents the boundary.
revoke insert, update, delete, truncate, references, trigger on public.cod_receipts from public;
revoke insert, update, delete, truncate, references, trigger on public.cod_receipts from anon;
revoke insert, update, delete, truncate, references, trigger on public.cod_receipts from authenticated;
grant select on public.cod_receipts to authenticated;

commit;
