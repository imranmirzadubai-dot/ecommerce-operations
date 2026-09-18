# P11-T183 — Test duplicate COD receipt

## Scope

Add deterministic database regression coverage for duplicate COD receipt handling through the authoritative `record_cod_receipt` command.

## Verification contract

- Existing receipts are checked by parcel before a new receipt is inserted.
- An identical duplicate is returned safely through the command's idempotency path.
- A duplicate with different receipt data is rejected with `23505` unique-violation semantics.
- The database-level `UNIQUE (parcel_id)` constraint independently enforces one receipt per parcel.
- Receipt domain-event and audit behavior remains on the original creation path.

## Test

`supabase/tests/database/103_duplicate_cod_receipt.sql` contains 10 pgTAP assertions.

## Dedicated CI

`.github/workflows/t183-duplicate-cod-receipt.yml` runs Supabase reset plus the dedicated regression test on pull requests targeting `main`.

No production business data is changed by this milestone.
