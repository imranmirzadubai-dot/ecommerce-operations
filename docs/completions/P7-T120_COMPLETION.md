# P7-T120 — Prepared Parcel Cancellation / Reversal

## Scope
Implement the `cancel_parcel` transactional command required by the Master Implementation Plan for cancelling a parcel while it remains `Prepared`.

## Existing implementation verified
The repository already contained the core migration `20260911160000_cancel_parcel_contract.sql` on `main`. This task reconciles that implementation into the current execution sequence and adds the missing client exposure and CI contract coverage.

## Implementation contract
- `cancel_parcel(uuid, text)` is exposed as a `SECURITY DEFINER` command with a pinned `search_path`.
- Requires an authenticated application role.
- Requires a non-empty idempotency key.
- Locks the parcel before cancellation.
- Permits cancellation only when parcel state is `Prepared`.
- Changes parcel state from `Prepared` to `Cancelled`.
- Reverses active `parcel_items` allocations instead of deleting them.
- Preserves allocation history for later reconstruction/re-allocation.
- Emits `ParcelCancelled` domain event with allocation-reversal metadata.
- Writes an immutable audit record.
- Uses shared command idempotency for retry-safe execution.
- Grants execution to `authenticated` and does not grant it to `anon`/`public`.
- Added client wrapper `cancelParcel`.
- Added database contract test 057 and CI coverage.

## Verification
- Core command exists on `main` in migration `20260911160000_cancel_parcel_contract.sql`.
- New contract test `057_cancel_prepared_parcel.sql` checks the lifecycle, authorization, reversal, audit/event and idempotency requirements.
- CI runs the new test as part of the local Supabase database suite.
- No production data is touched.
