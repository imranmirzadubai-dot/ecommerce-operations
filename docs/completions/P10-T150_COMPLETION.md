# P10-T150 — Implement NDR to In Transit retry

## Scope
Implement the authoritative lifecycle transition from `NDR` back to `In Transit` for another delivery attempt.

## Implementation
- Added `public.retry_ndr_parcel(uuid,text,text)` as a `SECURITY DEFINER` transactional command.
- Requires an authenticated `Operations` or `Admin` profile.
- Locks the parcel row with `FOR UPDATE` before validating/mutating state.
- Accepts only parcels currently in `NDR`.
- Transitions the parcel to `In Transit` without altering the NDR delivery-outcome history.
- Records an `NDR Retry` order event and an audit record in the same transaction.
- Uses command idempotency for safe retries.
- Revokes anonymous/public execute and grants execute to `authenticated`.
- Added the matching TypeScript client wrapper `retryNdrParcel`.
- Added dedicated regression test `071_ndr_in_transit_retry.sql` and CI execution.

## Boundary
T150 implements only `NDR → In Transit` retry. Later NDR follow-up transitions remain subsequent milestones.

## Safety
No production data was modified.
