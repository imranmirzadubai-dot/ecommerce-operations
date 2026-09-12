begin;

create unique index if not exists cod_receipts_parcel_id_unique_idx
  on public.cod_receipts (parcel_id);

alter table public.cod_receipts enable row level security;
revoke all on public.cod_receipts from anon;
revoke all on public.cod_receipts from authenticated;
grant select on public.cod_receipts to authenticated;

commit;
