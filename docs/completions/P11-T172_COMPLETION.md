# P11-T172 — Expected Amount Snapshot

Implements authoritative COD receipt expected-amount snapshot sourcing from the parcel COD allocation.

- The receipt command no longer accepts a client-supplied expected snapshot.
- The authoritative `cod_obligation_allocations.expected_amount` row is locked and used as the snapshot source.
- Receipt entry rejects parcels without an expected COD allocation.
- Existing role boundary, idempotency, audit, and domain-event behavior is preserved.
- Added database regression coverage and dedicated CI workflow.
- No production business data changed.
