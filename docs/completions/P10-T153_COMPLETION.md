# P10-T153 — Implement direct In Transit to Delivered

## Implementation

Established and regression-tested the direct `In Transit → Delivered` lifecycle through the authoritative `record_delivery_outcome` command.

- The command requires an `In Transit` parcel before applying a delivery outcome.
- `Delivered` is an explicit supported outcome.
- Parcel state mutation, immutable delivery outcome, order event, and audit record remain within the authoritative transaction.
- Row locking, Operations/Admin authorization, pinned `search_path`, and command idempotency remain intact.
- Added dedicated database regression coverage in test `075_direct_in_transit_delivered.sql`.
- Added test 075 to CI.

## Boundary

T153 covers the direct `In Transit → Delivered` transition only. It does not introduce a parallel mutation path.

## Safety

No production data was modified.

## Integration gate

This task remains **In Progress** until its PR is independently approved, merged to `main`, followed by green main CI and fresh-main verification.
