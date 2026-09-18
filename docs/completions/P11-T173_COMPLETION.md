# P11-T173 — COD Variance / Exception State

Implements database-authoritative COD receipt variance state.

- Exact expected-versus-received collection is recorded as `Received`.
- Any variance is forced to `Exception` before the receipt row is inserted.
- The decision uses the authoritative `expected_amount_snapshot` and `received_amount` fields.
- The trigger function is SECURITY DEFINER with a controlled search path and is not directly executable by application roles.
- Added database regression coverage and dedicated CI workflow.
- No production business data changed.
