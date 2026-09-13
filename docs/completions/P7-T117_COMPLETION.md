# P7-T117 — Exact Integer Allocation Invariant

## Status
COMPLETE — implementation verified and regression coverage added.

## Scope
The locked v4.0 contract requires parcel allocation quantities to remain INTEGER and requires active allocated quantity for an order item to never exceed its ordered quantity.

## Implementation baseline
The authoritative implementation was already present in `20260911170000_parcel_allocation_invariants.sql`:

- `public.parcel_items.quantity` is `integer not null check (quantity > 0)`.
- `public.order_items.quantity` is `integer not null check (quantity > 0)`.
- `public.assert_order_item_allocation_invariant(uuid)` serializes the order item row and rejects active allocated quantity greater than ordered quantity.
- `trg_validate_parcel_item_allocation` applies the invariant to parcel-item writes.
- `trg_validate_parcel_state_allocation` protects terminal physical outcomes.
- Historical `Released` / `Reversed` allocations do not consume active allocation quantity.

P7-T117 closes the explicit CI verification gap rather than duplicating or weakening an already-correct database invariant.

## Verification changes
1. Added `supabase/tests/database/054_exact_integer_allocation_invariant.sql` with explicit assertions that both order-item and parcel-item quantities are PostgreSQL `integer` columns with positive-value constraints, plus checks for the canonical invariant helper and allocation trigger.
2. Added the dedicated regression test to the main CI database-test command so this protection is continuously verified on feature branches and pull requests.
3. Preserved the existing over-allocation, reversal-history, terminal-quantity, trigger and RLS coverage in the existing invariant harness without forcing that legacy harness into the new CI gate.

## Acceptance
- Fractional allocation quantities cannot be represented by the schema because the authoritative quantity columns are INTEGER.
- Zero/negative quantities are rejected by schema constraints.
- Active allocation cannot exceed ordered quantity.
- Concurrent allocation is serialized on the order-item row.
- Released/Reversed history does not consume active quantity.
- Terminal physical quantity remains bounded by ordered quantity.

## Evidence
- Main baseline merge: PR #10 merge commit `5b082302d2bb2304a65fc565976882e94ef212e1`.
- Existing invariant implementation: `supabase/migrations/20260911170000_parcel_allocation_invariants.sql`.
- New regression test: `supabase/tests/database/054_exact_integer_allocation_invariant.sql`.
- Final CI run #619 / run `34733793751`: quality and Local Supabase database jobs PASS.

No production data was used or modified.
