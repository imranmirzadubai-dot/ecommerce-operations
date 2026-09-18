# P11-T181 — Test exact COD match

## Scope

Add dedicated regression coverage for the exact COD-match reconciliation contract introduced by P11-T180.

## Verification contract

- The authoritative reconciliation function exists with the locked signature.
- The function remains `SECURITY DEFINER`, `STABLE`, and search-path controlled.
- Exact receipt/effective amount equality is evaluated explicitly.
- Exact equality maps to `Reconciled`.
- COD obligation, parcel allocation, and receipt totals remain separately exposed.
- Outstanding amount is derived from effective amount less received amount.
- Non-exact receipt states remain distinguishable.
- Allocation completeness is required before reconciliation can be considered complete.
- Receipt variance uses immutable receipt snapshots.
- The reconciliation projection remains read-only.

## Test

`supabase/tests/database/101_exact_cod_match.sql` — 10 pgTAP assertions.

Dedicated CI workflow: `.github/workflows/t181-exact-cod-match.yml`.

No production business data is changed.
