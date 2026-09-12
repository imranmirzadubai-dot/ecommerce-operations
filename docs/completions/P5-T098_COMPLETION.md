# P5-T098 — Lock `original_amount` After Confirmation

**Status:** Complete
**Phase:** P5 — Customer & Order Core
**Task:** Lock `original_amount` after confirmation

## Contract

The locked Master Implementation Plan v4.0 requires the original order amount to become immutable after confirmation. `orders.original_amount` is the authoritative original commercial amount and must remain untouched after confirmation.

## Implementation

Added migration:

- `supabase/migrations/20260913110000_original_amount_immutability.sql`

The migration adds a `BEFORE UPDATE` trigger on `public.orders` that rejects any change to `original_amount` once an order has left `Draft`. It also rejects changing `original_amount` in the same update that transitions the order out of `Draft`, preventing a confirmation-path bypass.

Pre-confirmation Draft edits remain permitted, preserving P5-T096 behavior.

## Verification

Added database contract test:

- `supabase/tests/database/045_original_amount_immutability.sql`

Updated the CI database suite to execute the new test and updated rebuild verification for the additional migration.

Final CI verification:

- Workflow: `CI`
- Run: **466**
- Run ID: **34718844086**
- Commit verified: `8735e4cb8b15c7f3b052a160b4b472c603a64119`
- Quality job: **success**
- Local Supabase database job: **success**
- Database reset from repository migrations and seed: **success**
- Database verification and customer/order core tests: **success**

## Scope / Gate Note

This task does not alter the previously identified Phase 1 foundation-gate reconciliation items or Phase 2 architecture-gate reconciliation items. Those remain deferred/not-started until the planned post-P5 reconciliation pass.
