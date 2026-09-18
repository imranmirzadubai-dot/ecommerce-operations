# P10-T155 — Implement Lost outcome

## Scope

Verify and regression-test the authoritative `record_delivery_outcome` command for the direct `In Transit → Lost` lifecycle outcome.

## Implementation boundary

The authoritative command already supports `Lost` as a delivery outcome. T155 adds dedicated regression coverage rather than introducing a parallel mutation path.

## Verification coverage

- Authoritative command exists with the expected signature.
- SECURITY DEFINER and pinned `search_path` boundary retained.
- `In Transit` remains an allowed delivery state.
- `Lost` remains an explicitly supported outcome.
- Parcel state mutation remains authoritative.
- Delivery outcome, order event and audit recording remain atomic.
- Command idempotency remains in place.
- Anonymous execute remains revoked and authenticated execute remains granted.
- Parcel row locking remains in place before mutation.
- Lifecycle timestamp recording remains present.

Dedicated regression: `supabase/tests/database/077_lost_outcome.sql`.

No production data changes.

## Integration gate

Branch verification must pass before integration. Final integration remains subject to independent approval, merge to `main`, green post-merge main CI, and fresh-main verification.
