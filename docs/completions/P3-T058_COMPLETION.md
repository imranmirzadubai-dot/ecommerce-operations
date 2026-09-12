# P3-T058 Completion

**Task:** P3-T058 — Enforce parcel-item allocation ceiling

## Result

PASS — schema-level enforcement is installed in staging. The database now rejects an active parcel-item allocation when the aggregate active allocation for an order item would exceed its ordered quantity. Released/Reversed allocations remain historical and are excluded from the active ceiling.

## Evidence

- Migration: `supabase/migrations/20260912103000_parcel_item_allocation_invariants.sql`
- Test: `supabase/tests/database/011_parcel_item_allocation_invariants.sql`
- Staging project: `mijbpvgxrxjaalimyqgm`
- Implementation commit: `a922df7905cabb3a5d543766d11fb64554ccce02`
- Verification commit: `826e606cbd3e968d3ccbce7b5aeb552599a4c852`

## Staging verification

- Allocation-enforcement trigger exists: PASS
- `parcel_items` RLS remains enabled: PASS
- Authenticated SELECT grant remains present: PASS
- No production changes made: PASS

A live behavioral fixture test could not be executed because the staging database currently has no customer/order fixture available for a safe transactional test. The implementation is therefore verified at the schema/catalog level, with the repository test supplied for fixture-enabled execution.

## TCR

`ECO-TCR-P3-T058-20260912-a922df79`
