# P11-T182 — Test partial/variance collection

## Scope

Add deterministic database regression coverage for partial and over/under COD collection against the authoritative `get_cod_financial_reconciliation(uuid)` projection.

## Verification contract

- Partial collection is classified as `Outstanding` when received COD is below effective amount.
- Collection above effective amount is classified as `Overcollected`.
- Receipt variance is derived from immutable `cod_receipts.expected_amount_snapshot` values.
- Outstanding amount is derived from effective amount less received amount.
- `Exception` remains distinct from ordinary collection variance.
- Allocation/receipt completeness continues to gate reconciliation.
- The reconciliation projection remains read-only.

## Test

`supabase/tests/database/102_partial_variance_collection.sql` contains 10 pgTAP assertions.

## Dedicated CI

`.github/workflows/t182-partial-variance-collection.yml` runs Supabase reset plus the dedicated regression test on pull requests targeting `main`.
