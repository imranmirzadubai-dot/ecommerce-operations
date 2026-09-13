# P3-T075 Completion

## Task
Write allocation invariant tests.

## Result
PASS — behavioral tests cover the parcel allocation quantity invariant and preservation of reversal history.

## Verified
- Allocation constraint trigger exists on `parcel_items`.
- Allocation enforcement function is `SECURITY DEFINER` with `search_path = pg_catalog, public`.
- Active allocation exceeding the corresponding order-item quantity is rejected.
- Reversed allocation no longer consumes active allocation quantity.
- Reversed allocation history remains retained.
- `parcel_items` RLS remains enabled.
- Authenticated direct `parcel_items` INSERT is denied at the grant layer.

## Test
`supabase/tests/database/026_allocation_invariant_behavior.sql`

## Staging verification
Behavioral SQL verification passed against staging, including the over-allocation rejection and reversal/reallocation path. The repository test is written for the pgTAP-capable test environment; no pgTAP execution is claimed where the staging runner is unavailable.

## Completion date
2026-09-12
