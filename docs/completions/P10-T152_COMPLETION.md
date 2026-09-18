# P10-T152 — Implement NDR to RTO

## Implementation

Implemented the authoritative NDR → RTO lifecycle transition by extending `record_delivery_outcome`.

- NDR parcels may transition only to `Delivered` or `RTO`.
- `RTO` sets `rto_at` and the parcel state transactionally.
- Existing row locking, Operations/Admin authorization, idempotency, immutable delivery outcome recording, order event, and audit recording are preserved.
- Added dedicated database regression coverage in test 073 and CI execution.
- No production data changes.

## Verification

CI must pass quality and database jobs before this task is considered branch-verified.

## Integration gate

This task remains **In Progress** until its PR is independently approved, merged to `main`, followed by green main CI and fresh-main verification.
