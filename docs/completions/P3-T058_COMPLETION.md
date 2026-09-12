# P3-T058 Completion

**Task:** P3-T058 — Enforce parcel-item allocation ceiling

## Result

PASS. Active parcel-item allocations are constrained so their total quantity for an order item cannot exceed the ordered quantity. Released/Reversed allocation rows remain historical and do not consume the active allocation ceiling.

## Evidence

- Migration: `supabase/migrations/20260912103000_parcel_item_allocation_invariants.sql`
- Test: `supabase/tests/database/011_parcel_item_allocation_invariants.sql`
- Staging project: `mijbpvgxrxjaalimyqgm`
- Migration commit: `a922df7905cabb3a5d543766d11fb64554ccce02`
- Test commit: `826e606cbd3e968d3ccbce7b5aeb552599a4c852`

## Verification

The staging verification for this task must confirm:

1. A total active allocation equal to ordered quantity succeeds.
2. An active allocation that would exceed ordered quantity is rejected with a check-violation domain constraint.
3. A Released/Reversed historical allocation does not count toward the active ceiling.
4. Existing parcel-item RLS and least-privilege grants remain unchanged.

No production changes were made.

## TCR

`ECO-TCR-P3-T058-20260912-a922df79`
