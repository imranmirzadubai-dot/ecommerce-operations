begin;

-- P11-T170: make the one-receipt-per-parcel rule explicit and named.
-- The foundation schema already enforced uniqueness through an inline UNIQUE
-- declaration. Reconcile that constraint to a stable, auditable name so the
-- invariant is explicit and independently regression-tested.
alter table public.cod_receipts
  drop constraint if exists cod_receipts_parcel_id_key;

alter table public.cod_receipts
  add constraint cod_receipts_one_per_parcel_key unique (parcel_id);

commit;
